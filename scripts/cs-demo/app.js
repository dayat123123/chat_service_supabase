'use strict';

const cfg = window.CS_DEMO;
const POLL_MS = 1500;
const HEARTBEAT_MS = 15000;

const OUTCOMES = [['answered', 'Terjawab'], ['follow_up', 'Perlu tindak lanjut'], ['complaint', 'Pengaduan'], ['other', 'Lainnya']];
const STATUS_LABEL = {
  open: 'Terbuka', claimed: 'Ditangani', waiting_customer: 'Menunggu nasabah', resolved: 'Selesai', closed: 'Ditutup',
};
const FLAG_LABEL = { complaint: 'Pengaduan', fraud: 'Fraud', vip: 'VIP' };
const EVENT_LABEL = {
  opened: 'Tiket dibuat', claimed: 'Diambil CS', released: 'Dilepas ke antrean', transfer_requested: 'Transfer diminta',
  transfer_rejected: 'Transfer ditolak', transfer_expired: 'Transfer kedaluwarsa', transfer_cancelled: 'Transfer dibatalkan',
  transferred: 'Ditransfer', reassigned: 'Dipindahkan supervisor', supervisor_joined: 'Supervisor bergabung',
  waiting_customer: 'Menunggu nasabah', customer_replied: 'Nasabah membalas', owner_away: 'CS pemilik tidak aktif',
  resolved: 'Diselesaikan', reopened: 'Dibuka kembali', closed: 'Ditutup', priority_changed: 'Prioritas berubah',
  flagged: 'Ditandai', rated: 'Dinilai nasabah', secret_request_blocked: 'Pesan CS ditahan',
  fake_cs_reported: 'Laporan CS palsu',
};
const TABS = [['open', 'Terbuka'], ['mine', 'Tiket saya'], ['resolved_today', 'Selesai hari ini']];

const topicNames = new Map();
const byId = (id) => document.getElementById(id);

function h(tag, attrs, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs || {})) {
    if (value === null || value === undefined || value === false) continue;
    if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
    else if (key === 'class') node.className = value;
    else node.setAttribute(key, value === true ? '' : value);
  }
  for (const child of children.flat(Infinity)) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child instanceof Node ? child : String(child));
  }
  return node;
}

function fill(node, ...children) {
  node.replaceChildren(...children.flat(Infinity).filter((child) => child !== null && child !== undefined && child !== false));
}

class ApiError extends Error {
  constructor(status, body) {
    const fromDatabase = /^(PT|PGRST|\d)/.test(body?.code || '');
    super(body?.details || body?.message || `HTTP ${status}`);
    this.status = status;
    this.code = fromDatabase ? body?.message : body?.code;
  }
}

async function call(url, { method = 'POST', token, body, profile } = {}) {
  const headers = { apikey: cfg.anonKey };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (profile) {
    headers['Content-Profile'] = profile;
    headers['Accept-Profile'] = profile;
  }
  const res = await fetch(url, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { message: text };
  }
  if (!res.ok) throw new ApiError(res.status, data);
  return data;
}

const rpc = (token, fn, args = {}) => call(`${cfg.api}/rest/v1/rpc/${fn}`, { token, body: args, profile: 'cs_api' });

function toast(message, kind = 'info') {
  const node = h('div', { class: `toast ${kind}` }, message);
  byId('toasts').append(node);
  setTimeout(() => node.remove(), 6000);
}

const fail = (err) => toast(err?.message || String(err), 'error');
const newId = () => crypto.randomUUID();
const topicName = (code) => topicNames.get(code) || code;

const sameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
const clock = (date) => `${String(date.getHours()).padStart(2, '0')}.${String(date.getMinutes()).padStart(2, '0')}`;

function stamp(iso) {
  if (!iso) return '-';
  const date = new Date(iso);
  if (sameDay(date, new Date())) return clock(date);
  return `${date.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}, ${clock(date)}`;
}

function dayLabel(date) {
  const today = new Date();
  const yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);
  if (sameDay(date, today)) return 'Hari ini';
  if (sameDay(date, yesterday)) return 'Kemarin';
  return date.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
}

function waitLabel(iso) {
  if (!iso) return '';
  const minutes = Math.max(0, Math.floor((Date.now() - new Date(iso)) / 60000));
  if (minutes < 60) return `${minutes}m`;
  return `${Math.floor(minutes / 60)}j ${minutes % 60}m`;
}

function timeKey(iso) {
  const m = /^(.*T\d\d:\d\d:\d\d)(?:\.(\d+))?(.*)$/.exec(iso || '');
  return m ? `${m[1]}.${(m[2] || '').padEnd(6, '0')}${m[3]}` : iso || '';
}

function mergeMessages(map, list) {
  let changed = false;
  for (const m of list || []) {
    const prev = map.get(m.id);
    if (!prev || prev.body !== m.body || prev.is_deleted !== m.is_deleted) {
      map.set(m.id, m);
      changed = true;
    }
  }
  return changed;
}

function sortedMessages(map) {
  return [...map.values()].sort((a, b) => timeKey(a.created_at).localeCompare(timeKey(b.created_at)) || a.id.localeCompare(b.id));
}

function newestCursor(map) {
  const list = sortedMessages(map);
  return list.length ? list[list.length - 1].cursor : null;
}

function renderMessages(container, map, viewer, handlers) {
  const nearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 80;
  const nodes = [];
  let lastDay = null;
  for (const m of sortedMessages(map)) {
    const date = new Date(m.created_at);
    if (!lastDay || !sameDay(lastDay, date)) nodes.push(h('div', { class: 'day-sep' }, h('span', {}, dayLabel(date))));
    lastDay = date;
    nodes.push(messageNode(m, viewer, handlers));
  }
  fill(container, nodes);
  if (nearBottom || container.dataset.filled !== 'yes') container.scrollTop = container.scrollHeight;
  container.dataset.filled = 'yes';
}

function messageNode(m, viewer, handlers) {
  if (m.kind === 'system' || m.kind === 'csat') {
    return h('div', { class: 'msg system' }, m.body || '', h('span', { class: 'time' }, clock(new Date(m.created_at))));
  }
  const fromCustomer = m.sender_role === 'customer';
  const mine = viewer === 'customer' ? fromCustomer : !fromCustomer;
  const staff = m.sender_role === 'agent' || m.sender_role === 'supervisor';
  const url = m.payload?.url;
  return h('div', { class: `msg ${mine ? 'mine' : 'theirs'}` },
    staff ? h('div', { class: 'who' }, m.sender_display_name || 'CS', h('span', { class: 'badge official' }, 'CS Resmi')) : null,
    h('div', { class: 'body' }, m.is_deleted ? '(pesan dihapus)' : m.body || ''),
    m.kind === 'help_link' && /^https:\/\//.test(url || '')
      ? h('a', { class: 'link', href: url, target: '_blank', rel: 'noopener noreferrer' }, url) : null,
    m.kind === 'quick_reply'
      ? h('div', { class: 'chips' }, (m.payload?.options || []).map((option) =>
        h('button', { type: 'button', disabled: viewer !== 'customer', onclick: () => handlers.reply?.(option) }, option)))
      : null,
    m.payload?.masked ? h('div', { class: 'masked' }, `Disamarkan otomatis: ${m.payload.masked.join(', ')}`) : null,
    h('div', { class: 'time' }, clock(new Date(m.created_at))));
}

const prioBadge = (priority) => h('span', { class: `prio ${String(priority).toLowerCase()}` }, priority);
const flagBadges = (flags) => (flags || []).map((f) => h('span', { class: `flag ${f}` }, FLAG_LABEL[f] || f));

async function loadTopics(token) {
  const topics = await rpc(token, 'topics', { p_language: 'id' });
  topics.forEach((t) => topicNames.set(t.code, t.name));
  return topics;
}

const customer = { user: null, token: null, home: null, messages: new Map(), cursor: null, polling: false };

const customerHandlers = {
  reply: (text) => customerSend(text),
};

function initCustomerPanel() {
  const select = h('select', { 'aria-label': 'Pilih nasabah' },
    cfg.customers.map((c) => h('option', { value: c.username }, `@${c.username}`)));
  fill(byId('c-login'), select,
    h('button', { type: 'button', class: 'primary', onclick: () => customerLogin(select.value) }, 'Masuk'));
  fill(byId('c-status'), 'Belum masuk.');
  byId('c-status').className = 'status';
  fill(byId('c-body'), h('p', { class: 'muted' },
    'Pilih nasabah lalu masuk. Login memakai token OLT tiruan lewat auth-bridge, sama seperti app contoh.'));
}

function buildCustomerShell() {
  fill(byId('c-login'), h('strong', {}, `@${customer.user.username}`),
    h('button', { type: 'button', onclick: customerLogout }, 'Keluar'));
  const input = h('textarea', { id: 'c-input', rows: 2, placeholder: 'Tulis pesan ke CS… (Enter untuk kirim)' });
  input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      customerSend();
    }
  });
  fill(byId('c-body'),
    h('div', { id: 'c-topics', class: 'topics hidden' }),
    h('div', { id: 'c-messages', class: 'messages' }),
    h('div', { id: 'c-rating', class: 'rating hidden' }),
    h('div', { class: 'composer' }, input,
      h('button', { type: 'button', class: 'primary', id: 'c-send', onclick: () => customerSend() }, 'Kirim')),
    h('div', { class: 'actions' },
      h('button', { type: 'button', id: 'c-complaint', onclick: customerComplaint }, 'Ajukan pengaduan'),
      h('button', { type: 'button', class: 'danger-ghost', onclick: customerReportFake }, 'Laporkan CS palsu'),
      h('button', { type: 'button', id: 'c-end', onclick: customerEnd }, 'Akhiri chat')));
}

async function renderCustomerTopics() {
  const topics = await loadTopics(customer.token);
  fill(byId('c-topics'),
    h('div', { class: 'topics-title' }, 'Apa yang bisa kami bantu? Pilih topik untuk membuat tiket.'),
    h('div', { class: 'topic-grid' }, topics.map((t) =>
      h('button', { type: 'button', class: t.urgent ? 'topic urgent' : 'topic', onclick: () => customerStart(t.code) }, t.name))));
}

async function customerLogin(username) {
  const user = cfg.customers.find((c) => c.username === username);
  try {
    const res = await call(`${cfg.api}/bridge/v1/exchange`, { body: { token: `mock:${user.id}:${user.username}` } });
    Object.assign(customer, { user, token: res.access_token, home: null, messages: new Map(), cursor: null });
    buildCustomerShell();
    await renderCustomerTopics();
    await pollCustomer();
  } catch (err) {
    fail(err);
  }
}

function customerLogout() {
  Object.assign(customer, { user: null, token: null, home: null, messages: new Map(), cursor: null });
  initCustomerPanel();
}

async function pollCustomer() {
  if (!customer.token || customer.polling) return;
  customer.polling = true;
  try {
    customer.home = await rpc(customer.token, 'support_home');
    const room = customer.home.room_id;
    if (room) {
      const args = { p_room_id: room, p_limit: 100 };
      if (customer.cursor) args.p_after = customer.cursor;
      const list = await rpc(customer.token, 'get_messages', args);
      if (mergeMessages(customer.messages, list)) {
        customer.cursor = newestCursor(customer.messages);
        renderMessages(byId('c-messages'), customer.messages, 'customer', customerHandlers);
        if (customer.home.unread_count > 0) await rpc(customer.token, 'mark_read', { p_room_id: room });
      }
    }
    renderCustomer();
  } catch (err) {
    if (err.status === 401) {
      customerLogout();
      toast('Sesi login nasabah habis, silakan masuk lagi', 'error');
    } else {
      console.warn(err);
    }
  } finally {
    customer.polling = false;
  }
}

function customerHeader(home) {
  const t = home?.ticket;
  const parts = [];
  if (!t || t.status === 'closed') {
    parts.push(t ? `Tiket #${t.ticket_number} ditutup. Pilih topik atau ketik pesan untuk membuat tiket baru.`
      : 'Belum ada tiket. Pilih topik untuk mulai.');
  } else {
    parts.push(h('div', { class: 'ticket-line' }, `#${t.ticket_number} · ${t.topic_name || topicName(t.topic)}`));
    if (t.status === 'open') {
      parts.push(t.queue_ahead > 0 ? `Menunggu CS · ${t.queue_ahead} tiket di depan Anda` : 'Menunggu CS');
    } else if (t.status === 'claimed') {
      parts.push('Ditangani oleh ', h('strong', {}, t.agent?.display_name || 'CS'), ' – CS Resmi');
    } else if (t.status === 'waiting_customer') {
      parts.push('Menunggu balasan Anda');
    } else if (t.status === 'resolved') {
      parts.push(t.reopen_until ? `Selesai · balas sebelum ${stamp(t.reopen_until)} untuk membuka kembali` : 'Selesai');
    }
  }
  if (t?.complaint) {
    parts.push(h('div', { class: 'sub' }, `Pengaduan diterima ${stamp(t.complaint.received_at)} · tenggat ${stamp(t.complaint.due_at)}`));
  }
  if (home && !home.service_open) {
    parts.push(h('div', { class: 'sub' }, `Di luar jam layanan · CS membalas mulai ${stamp(home.next_open_at)}`));
  }
  return parts;
}

function renderCustomer() {
  if (!byId('c-messages')) return;
  const home = customer.home;
  const t = home?.ticket;
  const active = Boolean(home?.active);
  const tone = { open: 'waiting', claimed: 'active', waiting_customer: 'waiting', resolved: 'done', closed: '' }[t?.status] || '';
  byId('c-status').className = `status ${tone}`;
  fill(byId('c-status'), ...customerHeader(home));
  const resolved = t?.status === 'resolved';
  byId('c-topics').classList.toggle('hidden', active || resolved);
  byId('c-complaint').disabled = !active;
  byId('c-end').disabled = !(active || resolved);
  renderRating(t);
}

function renderRating(t) {
  const box = byId('c-rating');
  const show = Boolean(t?.can_rate);
  box.classList.toggle('hidden', !show);
  if (!show || box.dataset.ticket === t.id) return;
  box.dataset.ticket = t.id;
  let value = 0;
  const stars = [1, 2, 3, 4, 5].map((n) => h('button', {
    type: 'button',
    class: 'star',
    'aria-label': `Nilai ${n}`,
    onclick: () => {
      value = n;
      stars.forEach((star, i) => star.classList.toggle('on', i < n));
    },
  }, '★'));
  const comment = h('input', { type: 'text', placeholder: 'Komentar (opsional)' });
  fill(box, h('div', {}, `Bagaimana pelayanan untuk tiket #${t.ticket_number}?`), h('div', { class: 'stars' }, stars), comment,
    h('button', {
      type: 'button',
      class: 'primary',
      onclick: async () => {
        if (!value) return toast('Pilih nilai 1–5 dulu', 'error');
        try {
          await rpc(customer.token, 'rate_ticket', { p_ticket_id: t.id, p_rating: value, p_comment: comment.value || null });
          toast('Terima kasih atas penilaiannya');
          await pollCustomer();
        } catch (err) {
          fail(err);
        }
      },
    }, 'Kirim nilai'));
}

async function customerStart(topic) {
  try {
    await rpc(customer.token, 'open_ticket', { p_topic: topic, p_language: 'id', p_screen: 'help' });
    await pollCustomer();
  } catch (err) {
    fail(err);
  }
}

async function customerSend(preset) {
  const input = byId('c-input');
  const text = (typeof preset === 'string' ? preset : input.value).trim();
  if (!text) return;
  try {
    const check = await rpc(customer.token, 'check_sensitive', { p_text: text });
    if (check.masked && !window.confirm(
      `Pesan berisi data sensitif (${check.kinds.join(', ')}). Data itu akan disamarkan sebelum disimpan. Tetap kirim?\n\n`
      + 'Ingat: CS kami tidak pernah meminta PIN, password, atau OTP.')) return;
    let room = customer.home?.room_id;
    if (!room) room = (await rpc(customer.token, 'support_home')).room_id;
    if (!room) return toast('Pilih topik dulu untuk membuat tiket', 'error');
    await rpc(customer.token, 'send_message', { p_room_id: room, p_body: text, p_client_id: newId() });
    if (typeof preset !== 'string') input.value = '';
    await pollCustomer();
  } catch (err) {
    fail(err);
  }
}

async function customerComplaint() {
  if (!window.confirm('Ajukan pengaduan resmi? Waktu pengaduan dicatat dan tenggat penyelesaian dihitung dalam hari kerja.')) return;
  try {
    await rpc(customer.token, 'request_complaint');
    toast('Pengaduan dicatat');
    await pollCustomer();
  } catch (err) {
    fail(err);
  }
}

async function customerReportFake() {
  const text = window.prompt('Ceritakan kejadiannya (misalnya ada yang mengaku CS dan meminta OTP):');
  if (!text) return;
  try {
    await rpc(customer.token, 'report_fake_cs', { p_description: text });
    toast('Laporan diterima dan langsung diprioritaskan (P1)');
    await pollCustomer();
  } catch (err) {
    fail(err);
  }
}

async function customerEnd() {
  const t = customer.home?.ticket;
  if (!t || !window.confirm(`Akhiri chat untuk tiket #${t.ticket_number}?`)) return;
  try {
    await rpc(customer.token, 'close_ticket', { p_ticket_id: t.id });
    await pollCustomer();
  } catch (err) {
    fail(err);
  }
}

const agent = {
  cur: null, me: null, lists: null, tab: 'open', selected: null, detail: null,
  messages: new Map(), cursor: null, polling: false, side: 'notes', owner: null,
};

const tok = () => agent.cur.token;

function initAgentPanel() {
  renderAgentHead();
  fill(byId('a-inbox'), h('p', { class: 'muted' }, 'Pilih CS demo di atas (token uji aal2, hanya profil dev).'));
  fill(byId('a-chat'), h('div', { class: 'empty' }, 'Belum ada tiket dipilih.'));
  fill(byId('a-side'));
}

function renderAgentHead() {
  const picker = h('div', { class: 'agent-pick' }, cfg.agents.map((a) =>
    h('button', { type: 'button', class: agent.cur?.id === a.id ? 'chip on' : 'chip', onclick: () => selectAgent(a) },
      `${a.name} · ${a.code}`)));
  const status = agent.me
    ? h('div', { class: 'status-switch' },
      [['online', 'Online'], ['break', 'Istirahat'], ['offline', 'Offline']].map(([value, label]) =>
        h('button', { type: 'button', class: agent.me.status === value ? `chip on ${value}` : 'chip', onclick: () => setAgentStatus(value) }, label)),
      h('span', { class: 'capacity' }, `Tiket aktif ${agent.me.active_tickets}/${agent.me.max_active_tickets}`))
    : null;
  fill(byId('a-login'), picker, status);
}

async function selectAgent(a) {
  Object.assign(agent, { cur: a, me: null, lists: null, selected: null, detail: null, messages: new Map(), cursor: null });
  fill(byId('a-chat'), h('div', { class: 'empty' }, 'Belum ada tiket dipilih.'));
  fill(byId('a-side'));
  try {
    await loadTopics(a.token);
  } catch (err) {
    fail(err);
  }
  await pollAgent();
}

async function setAgentStatus(status) {
  try {
    agent.me = await rpc(tok(), 'agent_set_status', { p_status: status, p_reason: status === 'break' ? 'Istirahat' : null });
    renderAgentHead();
    await pollAgent();
  } catch (err) {
    fail(err);
  }
}

async function pollAgent() {
  if (!agent.cur || agent.polling) return;
  agent.polling = true;
  try {
    const [me, lists] = await Promise.all([rpc(tok(), 'agent_me'), rpc(tok(), 'ticket_lists')]);
    agent.me = me;
    agent.lists = lists;
    renderAgentHead();
    renderTicketList();
    if (agent.selected) await refreshAgentChat();
  } catch (err) {
    if (err.status === 401) toast('Token CS demo kedaluwarsa. Jalankan ulang make cs-demo.', 'error');
    else console.warn(err);
  } finally {
    agent.polling = false;
  }
}

function heartbeat() {
  if (agent.cur && agent.me && agent.me.status !== 'offline') rpc(tok(), 'agent_heartbeat').catch(() => {});
}

function renderTicketList() {
  const lists = agent.lists || { open: [], mine: [], resolved_today: [], transfers_in: [] };
  const tickets = lists[agent.tab] || [];
  const canClaim = agent.me?.status === 'online' && agent.me.active_tickets < agent.me.max_active_tickets;
  fill(byId('a-inbox'),
    h('div', { class: 'tabs' }, TABS.map(([value, label]) => h('button', {
      type: 'button',
      class: agent.tab === value ? 'tab on' : 'tab',
      onclick: () => {
        agent.tab = value;
        renderTicketList();
      },
    }, `${label} (${(lists[value] || []).length})`))),
    (lists.transfers_in || []).map((x) => h('div', { class: 'offer' },
      h('div', { class: 'row' }, h('strong', {}, `Transfer dari ${x.from_name}`), prioBadge(x.ticket.priority)),
      h('div', { class: 'preview' }, x.note),
      h('div', { class: 'row' },
        h('button', { type: 'button', class: 'primary', onclick: () => respondTransfer(x.id, true) }, 'Terima'),
        h('button', { type: 'button', onclick: () => respondTransfer(x.id, false) }, 'Tolak')))),
    tickets.length ? tickets.map((t) => ticketRow(t, canClaim)) : h('p', { class: 'muted' },
      agent.tab === 'open' ? 'Tidak ada tiket terbuka.' : 'Belum ada tiket.'),
    agent.tab === 'open' && !canClaim
      ? h('p', { class: 'muted' }, agent.me?.status !== 'online' ? 'Set status Online untuk mengambil tiket.' : 'Batas tiket aktif sudah penuh.')
      : null);
}

function ticketRow(t, canClaim) {
  const since = t.waiting_since || t.queued_at;
  const minutes = since ? Math.floor((Date.now() - new Date(since)) / 60000) : 0;
  const tone = minutes >= 15 ? 'late' : minutes >= 5 ? 'warn' : '';
  return h('div', { class: `session-row ${agent.selected === t.id ? 'on' : ''} ${t.status === 'open' ? tone : ''}`, onclick: () => selectTicket(t.id) },
    h('div', { class: 'row' }, h('strong', {}, t.customer?.display_name || 'Nasabah'), prioBadge(t.priority), flagBadges(t.flags),
      t.unread_count ? h('span', { class: 'unread' }, t.unread_count) : null),
    h('div', { class: 'muted' }, `#${t.ticket_number} · ${topicName(t.topic)}`
      + (t.status === 'open' ? ` · menunggu ${waitLabel(since)}` : ` · ${STATUS_LABEL[t.status] || t.status}`)),
    t.returned_reason && t.status === 'open' ? h('div', { class: 'returned' }, `Dikembalikan: ${t.returned_reason}`) : null,
    t.preview ? h('div', { class: 'preview' }, `“${t.preview}”`) : null,
    t.status === 'open'
      ? h('button', {
        type: 'button',
        class: 'primary claim',
        disabled: !canClaim,
        onclick: (event) => {
          event.stopPropagation();
          claim(t, event.currentTarget);
        },
      }, 'Ambil')
      : null);
}

async function claim(t, button) {
  button.disabled = true;
  button.textContent = 'Mengambil…';
  try {
    await rpc(tok(), 'claim_ticket', { p_ticket_id: t.id });
    agent.tab = 'mine';
    await pollAgent();
    selectTicket(t.id);
  } catch (err) {
    fail(err);
    await pollAgent();
  }
}

async function respondTransfer(id, accept) {
  try {
    const t = await rpc(tok(), 'respond_transfer', { p_transfer_id: id, p_accept: accept, p_reason: accept ? null : 'Sedang penuh' });
    await pollAgent();
    if (accept) selectTicket(t.id);
  } catch (err) {
    fail(err);
  }
}

function selectTicket(id) {
  Object.assign(agent, { selected: id, detail: null, messages: new Map(), cursor: null, owner: null });
  buildAgentChat();
  renderTicketList();
  refreshAgentChat();
}

function isOwner() {
  const t = agent.detail;
  return Boolean(t && t.owner?.id === agent.cur.id && (t.status === 'claimed' || t.status === 'waiting_customer'));
}

function greeting() {
  return `Halo ${agent.detail?.customer?.display_name || 'Bapak/Ibu'}, saya ${agent.cur.name} dari CS OLT. Ada yang bisa saya bantu?`;
}

function buildAgentChat() {
  const input = h('textarea', { id: 'a-input', rows: 2, placeholder: 'Balas nasabah… (Enter untuk kirim)' });
  input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      agentSend();
    }
  });
  fill(byId('a-chat'),
    h('div', { id: 'a-chat-head', class: 'chat-head' }),
    h('div', { id: 'a-alert' }),
    h('div', { id: 'a-messages', class: 'messages' }),
    h('div', { id: 'a-owner', class: 'owner-tools' },
      h('div', { class: 'quick' },
        h('button', { type: 'button', onclick: () => agentSend(greeting()) }, 'Salam'),
        h('button', { type: 'button', onclick: () => agentSend('Mohon tunggu sebentar ya, saya cek dulu.') }, 'Mohon tunggu'),
        h('button', {
          type: 'button',
          onclick: () => agentSend('Apakah Anda sudah mencoba keluar lalu masuk ulang?', 'quick_reply', { options: ['Sudah', 'Belum'] }),
        }, 'Tombol Sudah/Belum'),
        h('button', {
          type: 'button',
          onclick: () => agentSend('Panduan reset password', 'help_link', { url: 'https://help.olt.co.id/reset-password' }),
        }, 'Tautan bantuan'),
        h('button', {
          type: 'button',
          class: 'danger-ghost',
          onclick: () => agentSend('Mohon kirimkan kode OTP Anda agar saya bisa bantu cek.'),
        }, 'Uji: minta OTP (ditahan)')),
      h('div', { class: 'composer' }, input,
        h('button', { type: 'button', class: 'primary', id: 'a-send', onclick: () => agentSend() }, 'Kirim')),
      h('div', { class: 'agent-actions' },
        h('button', { type: 'button', onclick: waitCustomer }, 'Tunggu nasabah'),
        h('button', { type: 'button', onclick: releaseTicket }, 'Lepas ke antrean'),
        h('span', { class: 'group' },
          h('select', { id: 'a-outcome', 'aria-label': 'Hasil' }, OUTCOMES.map(([value, label]) => h('option', { value }, label))),
          h('input', { id: 'a-summary', type: 'text', placeholder: 'Ringkasan singkat' }),
          h('button', { type: 'button', class: 'primary', onclick: resolveTicket }, 'Selesaikan')))),
    h('div', { id: 'a-readonly', class: 'readonly hidden' }));
}

function renderAgentChatHead() {
  const t = agent.detail;
  const head = byId('a-chat-head');
  if (!head || !t) return;
  const owner = isOwner();
  byId('a-owner').classList.toggle('hidden', !owner);
  const readonly = byId('a-readonly');
  readonly.classList.toggle('hidden', owner);
  if (!owner) {
    const canClaim = t.status === 'open' && agent.me?.status === 'online' && agent.me.active_tickets < agent.me.max_active_tickets;
    const notes = {
      resolved: 'Tiket selesai. Bila nasabah membalas dalam masa buka kembali, tiket kembali ke CS pemilik.',
      closed: 'Tiket ditutup. Pesan nasabah berikutnya membuat tiket baru.',
    };
    fill(readonly, t.status === 'open'
      ? [h('span', {}, 'Pratinjau hanya-baca. Ambil tiket ini untuk membalas.'),
        h('button', { type: 'button', class: 'primary', disabled: !canClaim, onclick: (event) => claim(t, event.currentTarget) }, 'Ambil tiket')]
      : notes[t.status] || `Ditangani oleh ${t.owner?.display_name} (${t.owner?.agent_code}). Kolom balas dinonaktifkan.`);
  }
  fill(head,
    h('div', { class: 'row' }, h('strong', {}, `#${t.ticket_number}`), prioBadge(t.priority), flagBadges(t.flags),
      h('span', { class: 'muted' }, `· ${topicName(t.topic)} · ${STATUS_LABEL[t.status] || t.status}`)),
    h('div', { class: 'muted' }, `${t.customer?.display_name} (@${t.customer?.username}) · dibuat ${stamp(t.created_at)}`
      + (t.owner ? ` · pemilik ${t.owner.id === agent.cur.id ? 'Anda' : t.owner.display_name}` : '')
      + (t.complaint_due_at ? ` · tenggat pengaduan ${stamp(t.complaint_due_at)}` : '')));
}

async function refreshAgentChat() {
  if (!agent.selected || !byId('a-messages')) return;
  try {
    agent.detail = await rpc(tok(), 'ticket_detail', { p_ticket_id: agent.selected });
    renderAgentChatHead();
    if (agent.owner !== isOwner()) {
      agent.owner = isOwner();
      loadSide();
    }
    const args = { p_room_id: agent.detail.room_id, p_limit: 100 };
    if (agent.cursor) args.p_after = agent.cursor;
    const list = await rpc(tok(), 'get_messages', args);
    if (mergeMessages(agent.messages, list)) {
      agent.cursor = newestCursor(agent.messages);
      renderMessages(byId('a-messages'), agent.messages, 'agent', {});
    }
    if (isOwner() && agent.detail.unread_count > 0) await rpc(tok(), 'mark_read', { p_room_id: agent.detail.room_id });
  } catch (err) {
    if (err.status === 404) fill(byId('a-messages'), h('div', { class: 'empty' }, 'Tiket ini tidak bisa dibuka lagi.'));
    else console.warn(err);
  }
}

async function agentSend(preset, kind = 'text', payload = {}) {
  const input = byId('a-input');
  const text = (typeof preset === 'string' ? preset : input.value).trim();
  if (!isOwner() || !text) return;
  try {
    const res = await rpc(tok(), 'agent_send_message', {
      p_ticket_id: agent.selected, p_body: text, p_client_id: newId(), p_kind: kind, p_payload: payload,
    });
    if (res.status === 'blocked') {
      fill(byId('a-alert'), h('div', { class: 'alert' }, res.message));
      return;
    }
    fill(byId('a-alert'));
    if (typeof preset !== 'string') input.value = '';
    await refreshAgentChat();
  } catch (err) {
    fail(err);
  }
}

async function ownerAction(fn, args, message) {
  try {
    await rpc(tok(), fn, { p_ticket_id: agent.selected, p_version: agent.detail.version, ...args });
    toast(message);
    await pollAgent();
  } catch (err) {
    fail(err);
    await pollAgent();
  }
}

const waitCustomer = () => ownerAction('wait_customer', {}, 'Status: menunggu nasabah');

function releaseTicket() {
  const reason = window.prompt('Alasan melepas tiket ke antrean (wajib):');
  if (reason && reason.trim().length >= 3) ownerAction('release_ticket', { p_reason: reason.trim() }, 'Tiket kembali ke antrean');
}

function resolveTicket() {
  const summary = byId('a-summary').value.trim();
  if (summary.length < 3) return toast('Isi ringkasan singkat dulu', 'error');
  ownerAction('resolve_ticket', { p_outcome: byId('a-outcome').value, p_summary: summary, p_tags: [] }, 'Tiket diselesaikan');
}

function loadSide() {
  const tabs = [['notes', 'Catatan internal'], ['history', 'Riwayat']];
  fill(byId('a-side'),
    h('div', { class: 'tabs' }, tabs.map(([value, label]) => h('button', {
      type: 'button',
      class: agent.side === value ? 'tab on' : 'tab',
      onclick: () => {
        agent.side = value;
        loadSide();
      },
    }, label))),
    h('div', { id: 'a-side-content' }));
  ({ notes: loadNotes, history: loadHistory })[agent.side]();
}

async function loadNotes() {
  const box = byId('a-side-content');
  const t = agent.detail;
  if (!t) {
    fill(box, h('p', { class: 'muted' }, 'Pilih tiket dulu.'));
    return;
  }
  const list = h('div');
  const input = h('textarea', { rows: 3, placeholder: 'Catatan untuk CS lain…' });
  fill(box,
    h('div', { class: 'internal-banner' }, 'Catatan internal · tidak terlihat nasabah'),
    list, input,
    h('button', {
      type: 'button',
      class: 'primary',
      onclick: async () => {
        if (!input.value.trim()) return;
        try {
          await rpc(tok(), 'add_note', { p_body: input.value, p_ticket_id: t.id });
          input.value = '';
          await renderNotes(list, t);
        } catch (err) {
          fail(err);
        }
      },
    }, 'Simpan catatan'));
  await renderNotes(list, t);
}

async function renderNotes(list, t) {
  try {
    const notes = await rpc(tok(), 'notes', { p_customer_id: t.customer.id });
    fill(list, ...(notes.length ? notes.map((n) => h('div', { class: `note ${n.kind}` },
      h('div', { class: 'note-meta' }, `${n.author ? n.author.display_name : 'Sistem'} · ${stamp(n.created_at)}`
        + (n.kind === 'handover' ? ' · serah terima' : '')),
      h('div', {}, n.body))) : [h('p', { class: 'muted' }, 'Belum ada catatan.')]));
  } catch (err) {
    fill(list, h('p', { class: 'muted' }, err.message));
  }
}

async function loadHistory() {
  const box = byId('a-side-content');
  const t = agent.detail;
  if (!t) {
    fill(box, h('p', { class: 'muted' }, 'Pilih tiket dulu.'));
    return;
  }
  try {
    const history = await rpc(tok(), 'customer_history', { p_customer_id: t.customer.id });
    fill(box,
      h('h4', {}, 'Perjalanan tiket ini'),
      h('ol', { class: 'timeline' }, (t.events || []).map((e) => h('li', {},
        h('strong', {}, EVENT_LABEL[e.type] || e.type), ` · ${e.actor_name || e.actor_type} · ${stamp(e.created_at)}`))),
      h('h4', {}, 'Riwayat tiket nasabah'),
      history.map((x) => h('div', { class: 'list-row' },
        `#${x.ticket_number || ''} · ${stamp(x.created_at)} · ${topicName(x.topic)} · ${STATUS_LABEL[x.status] || x.status}`
        + (x.rating ? ` · ★${x.rating}` : '') + (x.agent ? ` · ${x.agent}` : ''))));
  } catch (err) {
    fill(box, h('p', { class: 'muted' }, err.message));
  }
}

function main() {
  if (!cfg) {
    fill(document.body, h('main', { class: 'missing' },
      h('h1', {}, 'Konfigurasi demo belum ada'),
      h('p', {}, 'Jalankan: make cs-demo (Windows: .\\make.ps1 cs-demo)')));
    return;
  }
  initCustomerPanel();
  initAgentPanel();
  setInterval(pollCustomer, POLL_MS);
  setInterval(pollAgent, POLL_MS);
  setInterval(heartbeat, HEARTBEAT_MS);
}

main();
