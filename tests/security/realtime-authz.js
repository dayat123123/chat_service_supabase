import http from 'k6/http';
import { Realtime, sleepMs } from '../load/lib/realtime.js';

export const options = { vus: 1, iterations: 1 };

const API = __ENV.API;
const ANON = __ENV.ANON_KEY;
const ROOM = __ENV.ROOM;

function result(verdict, actor, probe, status, detail) {
  console.log(`RESULT ${JSON.stringify({ verdict, actor, probe, status: String(status), detail: detail || '' })}`);
}

async function joinStatus(rt, fn) {
  try {
    const reply = await fn();
    return reply.status || 'unknown';
  } catch (e) {
    return String(e.message || e);
  }
}

export default async function () {
  const attacker = new Realtime(API, ANON, __ENV.JWT);
  const victim = new Realtime(API, ANON, __ENV.VICTIM_JWT);
  await attacker.connect();
  await victim.connect();

  const seen = { attacker: 0, victim: 0, attackerBroadcast: 0 };
  const errors = [];
  const privStatus = await joinStatus(attacker, () => attacker.joinPrivate(`room:${ROOM}`, {
    broadcast: () => { seen.attackerBroadcast += 1; },
    system: (p) => { if (p && p.status === 'error') errors.push(p.message || 'error'); },
    error: (ev) => errors.push(ev),
  }));
  await sleepMs(1500);
  const privDenied = privStatus !== 'ok' || errors.length > 0;
  result(privDenied ? 'ok' : 'FAIL', 'nasabah', 'join kanal privat room:<DM orang lain>', privStatus, errors.join(','));

  const injected = { attacker: 0, victim: 0 };
  const victimPriv = await joinStatus(victim, () => victim.joinPrivate(`room:${ROOM}`, {
    broadcast: (p) => {
      if (p && p.event === 'probe_inject') injected[(p.payload && p.payload.from) || 'x'] += 1;
    },
  }));
  result(victimPriv === 'ok' ? 'ok' : 'FAIL', 'lt_sec_a', 'kontrol: anggota room bisa join kanal privat', victimPriv, '');

  const broadcast = (jwt, from) => http.post(`${API}/realtime/v1/api/broadcast`, JSON.stringify({
    messages: [{ topic: `room:${ROOM}`, event: 'probe_inject', payload: { from }, private: true }],
  }), { headers: { apikey: ANON, Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' } });
  const injAttacker = broadcast(__ENV.JWT, 'attacker');
  const injVictim = broadcast(__ENV.VICTIM_JWT, 'victim');
  await sleepMs(3000);
  result(injected.attacker === 0 ? 'ok' : 'FAIL', 'nasabah', 'REST broadcast ke kanal privat room orang lain tidak sampai', `${injAttacker.status}/${injected.attacker}`, '');
  result(injected.victim === 0 ? 'ok' : 'FAIL', 'lt_sec_a',
    'anggota room tidak boleh mengirim event selain typing (mis. message_hidden/room_state/reaction) ke kanal room:<id>',
    `${injVictim.status}/${injected.victim}`, 'event buatan klien diterima anggota lain sebagai sinyal server');

  await joinStatus(attacker, () => attacker.joinTable('probe-messages-a', 'messages', `room_id=eq.${ROOM}`, {
    change: () => { seen.attacker += 1; },
  }));
  await joinStatus(victim, () => victim.joinTable('probe-messages-v', 'messages', `room_id=eq.${ROOM}`, {
    change: () => { seen.victim += 1; },
  }));
  await sleepMs(2500);

  const res = http.post(`${API}/rest/v1/rpc/send_message`, JSON.stringify({ p_room_id: ROOM, p_body: `probe realtime ${Date.now()}` }), {
    headers: { apikey: ANON, Authorization: `Bearer ${__ENV.VICTIM_JWT}`, 'Content-Type': 'application/json' },
  });
  await sleepMs(5000);
  result(res.status === 200 ? 'ok' : 'FAIL', 'lt_sec_a', 'kontrol: anggota mengirim pesan', res.status, '');
  result(seen.victim > 0 ? 'ok' : 'FAIL', 'lt_sec_a', 'kontrol: anggota menerima postgres_changes', seen.victim, '');
  result(seen.attacker === 0 ? 'ok' : 'FAIL', 'nasabah', 'postgres_changes messages room orang lain tidak terkirim', seen.attacker, '');
  result(seen.attackerBroadcast === 0 ? 'ok' : 'FAIL', 'nasabah', 'broadcast kanal privat room orang lain tidak terkirim', seen.attackerBroadcast, '');
  attacker.close();
  victim.close();
}
