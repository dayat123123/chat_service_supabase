package agent

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"olt-social/backup/internal/pg"
	"olt-social/backup/internal/runner"
	"olt-social/backup/internal/wal"
)

type Decision struct {
	Drop     bool
	Detach   bool
	Create   bool
	NeedBase bool
	Lost     bool
}

func Decide(knownSystem, system string, slot pg.SlotStatus, haveLocal, force bool) Decision {
	var d Decision
	if slot.Lost() {
		return Decision{Drop: true, Create: true, NeedBase: true, Lost: true, Detach: haveLocal}
	}
	if !slot.Exists {
		d.Create = true
		if haveLocal {
			d.Detach, d.NeedBase = true, true
		}
	}
	if knownSystem != "" && knownSystem != system {
		d.NeedBase = true
		d.Detach = d.Detach || haveLocal
	}
	if force && haveLocal {
		d.Detach, d.NeedBase = true, true
	}
	return d
}

func (a *Agent) receiverWanted() bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.configured && a.repoReady
}

func (a *Agent) setStreaming(on bool, problem string) {
	a.mu.Lock()
	changed := a.streaming != on || a.walErr != problem
	a.streaming, a.walErr = on, problem
	a.mu.Unlock()
	if changed {
		a.kickHeartbeat()
	}
}

func (a *Agent) receiverLoop(ctx context.Context) {
	var backoff time.Duration
	for ctx.Err() == nil {
		if !a.receiverWanted() {
			a.setStreaming(false, "")
			a.dropSlotIfDisabled(ctx)
			a.idle(ctx, a.opts.Tick, a.wakeRecv)
			continue
		}
		started := a.now()
		err := a.receive(ctx)
		if ctx.Err() != nil {
			a.setStreaming(false, "")
			return
		}
		if a.now().Sub(started) > 2*time.Minute {
			backoff = 0
		}
		backoff = grow(backoff, a.opts.BackoffMin, a.opts.BackoffMax)
		problem := "WAL streaming berhenti"
		if err != nil {
			problem = clip(err.Error())
		}
		if a.receiverWanted() {
			a.mu.Lock()
			a.restarts++
			a.mu.Unlock()
			a.setStreaming(false, problem)
			a.log.Warn("WAL receiver stopped; restarting", "error", problem, "retry_in", backoff.String())
		}
		a.idle(ctx, backoff, a.wakeRecv)
	}
}

func (a *Agent) dropSlotIfDisabled(ctx context.Context) {
	a.mu.Lock()
	due := a.off && !a.dropped
	a.mu.Unlock()
	if !due {
		return
	}
	c, cancel := context.WithTimeout(ctx, a.opts.RequestTimeout)
	defer cancel()
	slot, err := a.opts.Database.Slot(c)
	if err == nil && slot.Exists && !slot.Active {
		err = a.opts.Database.DropSlot(c)
		if err == nil {
			a.log.Info("Backup is disabled; replication slot dropped so the database stops keeping WAL", "slot", pg.Slot)
		}
	}
	if err != nil {
		a.log.Debug("Could not check the replication slot while backup is disabled", "error", err)
		return
	}
	a.mu.Lock()
	a.dropped = true
	a.mu.Unlock()
}

func (a *Agent) haveLocalWAL() bool {
	files, err := wal.List(a.walDir())
	if err != nil {
		return true
	}
	for _, f := range files {
		if !f.History {
			return true
		}
	}
	return false
}

func (a *Agent) receive(ctx context.Context) error {
	c, cancel := context.WithTimeout(ctx, a.opts.RequestTimeout)
	sys, err := a.opts.Database.Identify(c)
	if err != nil {
		cancel()
		return fmt.Errorf("tidak bisa terhubung ke database untuk replikasi: %s", runner.Detail(err))
	}
	slot, err := a.opts.Database.Slot(c)
	cancel()
	if err != nil {
		return fmt.Errorf("status slot replikasi tidak bisa dibaca: %s", runner.Detail(err))
	}
	a.mu.Lock()
	known, force := a.persist.SystemID, a.forceReset
	a.forceReset = false
	a.mu.Unlock()
	d := Decide(known, sys.ID, slot, a.haveLocalWAL(), force)
	if d.Lost {
		a.log.Error("Replication slot was lost; WAL continuity is broken and a new base backup will be taken", "slot", pg.Slot)
	}
	if d.Drop {
		if err := a.opts.Database.DropSlot(ctx); err != nil {
			return fmt.Errorf("slot replikasi yang hilang tidak bisa dihapus: %s", runner.Detail(err))
		}
	}
	if d.Detach {
		if err := a.detachWAL(); err != nil {
			return fmt.Errorf("folder WAL lama tidak bisa dipindahkan: %v", err)
		}
	}
	a.mu.Lock()
	a.persist.SystemID = sys.ID
	if d.NeedBase {
		now := a.now()
		a.persist.NeedBase, a.persist.ResetAt = true, now
		if d.Lost {
			a.persist.SlotLostAt = now
		}
	}
	a.saveLocked()
	a.mu.Unlock()
	if d.NeedBase {
		a.kickHeartbeat()
		notify(a.wakeJob)
	}
	if d.Create {
		if err := a.opts.Database.CreateSlot(ctx); err != nil {
			return fmt.Errorf("slot replikasi tidak bisa dibuat: %s", runner.Detail(err))
		}
		a.log.Info("Replication slot ready", "slot", pg.Slot)
	}
	a.mu.Lock()
	a.recvErr = ""
	a.mu.Unlock()
	proc, err := a.opts.Database.StartReceiver(ctx, a.walDir(), a.receiverLine)
	if err != nil {
		return fmt.Errorf("pg_receivewal tidak bisa dijalankan: %v", err)
	}
	return a.supervise(ctx, proc)
}

func (a *Agent) receiverLine(line string) {
	a.log.Debug("pg_receivewal", "line", line)
	switch {
	case strings.Contains(line, "starting log streaming"):
		a.mu.Lock()
		problem := ""
		if a.slotRisk {
			problem = slotRiskText
		}
		a.mu.Unlock()
		a.setStreaming(true, problem)
		a.log.Info("WAL streaming started", "detail", strings.TrimPrefix(line, "pg_receivewal: "))
	case strings.Contains(line, "error:") || strings.Contains(line, "FATAL:"):
		a.mu.Lock()
		a.recvErr = strings.TrimSpace(strings.TrimPrefix(line, "pg_receivewal: error: "))
		if strings.Contains(line, "has already been removed") || strings.Contains(line, "is not in this server's history") {
			a.forceReset = true
		}
		a.mu.Unlock()
	}
}

const slotRiskText = "Slot replikasi hampir kehilangan WAL: pengiriman WAL tertinggal melebihi max_slot_wal_keep_size"

func (a *Agent) supervise(ctx context.Context, proc runner.Process) error {
	ticker := time.NewTicker(a.opts.SlotCheck)
	defer ticker.Stop()
	for {
		select {
		case <-proc.Done():
			err := proc.Wait()
			a.mu.Lock()
			last := a.recvErr
			a.mu.Unlock()
			switch {
			case ctx.Err() != nil:
				return ctx.Err()
			case last != "":
				return fmt.Errorf("pg_receivewal berhenti: %s", last)
			case err != nil:
				return fmt.Errorf("pg_receivewal berhenti: %s", runner.Detail(err))
			default:
				return errors.New("pg_receivewal berhenti")
			}
		case <-ticker.C:
			a.checkSlot(ctx, proc)
		case <-a.wakeRecv:
			if !a.receiverWanted() {
				proc.Interrupt()
			}
		}
	}
}

func (a *Agent) checkSlot(ctx context.Context, proc runner.Process) {
	c, cancel := context.WithTimeout(ctx, a.opts.RequestTimeout)
	slot, err := a.opts.Database.Slot(c)
	cancel()
	if err != nil {
		a.log.Debug("Could not read the replication slot status", "error", err)
		return
	}
	if slot.Lost() || !slot.Exists {
		a.log.Warn("Replication slot is gone while streaming; restarting the receiver", "wal_status", slot.WALStatus)
		proc.Interrupt()
		return
	}
	a.mu.Lock()
	changed := a.slotRisk != slot.AtRisk()
	a.slotRisk = slot.AtRisk()
	streaming := a.streaming
	a.mu.Unlock()
	if !changed || !streaming {
		return
	}
	if slot.AtRisk() {
		a.log.Warn("Replication slot is close to losing WAL", "wal_status", slot.WALStatus)
		a.setStreaming(true, slotRiskText)
	} else {
		a.setStreaming(true, "")
	}
}

func (a *Agent) detachWAL() error {
	a.walMu.Lock()
	defer a.walMu.Unlock()
	target := a.dir(detachedPrefix + a.now().UTC().Format(stampLayout))
	if _, err := os.Stat(target); err == nil {
		target += fmt.Sprintf("-%d", a.now().UnixNano())
	}
	if err := os.Rename(a.walDir(), target); err != nil {
		return err
	}
	a.log.Warn("Local WAL moved aside; it is still sent offsite before removal", "path", filepath.Base(target))
	return os.MkdirAll(a.walDir(), 0o700)
}

func detachedAt(dir string) (time.Time, bool) {
	stamp := strings.TrimPrefix(filepath.Base(dir), detachedPrefix)
	if len(stamp) < len(stampLayout) {
		return time.Time{}, false
	}
	t, err := time.Parse(stampLayout, stamp[:len(stampLayout)])
	return t, err == nil
}
