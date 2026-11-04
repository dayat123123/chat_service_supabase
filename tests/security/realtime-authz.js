import http from 'k6/http';
import encoding from 'k6/encoding';
import { Realtime, sleepMs } from '../load/lib/realtime.js';

export const options = { vus: 1, iterations: 1 };

const API = __ENV.API;
const ANON = __ENV.ANON_KEY;
const ROOM = __ENV.ROOM;
const SPOOFED = ['message', 'message_hidden', 'room_state', 'reaction', 'receipt', 'typing', 'probe_inject'];

function result(verdict, actor, probe, status, detail) {
  console.log(`RESULT ${JSON.stringify({ verdict, actor, probe, status: String(status), detail: detail || '' })}`);
}

function subject(jwt) {
  try {
    return JSON.parse(encoding.b64decode(jwt.split('.')[1], 'rawurl', 's')).sub || '';
  } catch (_) {
    return '';
  }
}

async function joinStatus(fn) {
  try {
    const reply = await fn();
    return reply.status || 'unknown';
  } catch (e) {
    return String(e.message || e);
  }
}

function rpc(jwt, fn, body) {
  return http.post(`${API}/rest/v1/rpc/${fn}`, JSON.stringify(body), {
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' },
  });
}

function restBroadcast(jwt, topic, event, payload) {
  return http.post(`${API}/realtime/v1/api/broadcast`, JSON.stringify({
    messages: [{ topic, event, payload, private: true }],
  }), { headers: { apikey: ANON, Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' } });
}

export default async function () {
  const victimId = subject(__ENV.VICTIM_JWT);
  const attacker = new Realtime(API, ANON, __ENV.JWT);
  const victim = new Realtime(API, ANON, __ENV.VICTIM_JWT);
  await attacker.connect();
  await victim.connect();

  const errors = [];
  let attackerBroadcast = 0;
  const privStatus = await joinStatus(() => attacker.joinPrivate(`room:${ROOM}`, {
    broadcast: () => { attackerBroadcast += 1; },
    system: (p) => { if (p && p.status === 'error') errors.push(p.message || 'error'); },
    error: (ev) => errors.push(ev),
  }));
  await sleepMs(1500);
  const privDenied = privStatus !== 'ok' || errors.length > 0;
  result(privDenied ? 'ok' : 'FAIL', 'nasabah', 'join kanal privat room:<DM orang lain>', privStatus, errors.join(','));

  const userErrors = [];
  const userStatus = await joinStatus(() => attacker.joinPrivate(`user:${victimId}`, {
    broadcast: () => { attackerBroadcast += 1; },
    system: (p) => { if (p && p.status === 'error') userErrors.push(p.message || 'error'); },
    error: (ev) => userErrors.push(ev),
  }));
  await sleepMs(1000);
  const userDenied = userStatus !== 'ok' || userErrors.length > 0;
  result(userDenied ? 'ok' : 'FAIL', 'nasabah', 'join kanal privat user:<nasabah lain>', userStatus, userErrors.join(','));

  const got = { spoof: 0, message: null, typing: null, activity: 0, presence: 0 };
  let sentId = '';
  const stamp = `probe broadcast ${Date.now()}`;
  const roomTopic = `realtime:room:${ROOM}`;
  const victimRoom = await joinStatus(() => victim.join(`room:${ROOM}`, {
    broadcast: { self: true, ack: false },
    presence: { key: victimId },
    postgres_changes: [],
    private: true,
  }, {
    broadcast: (p) => {
      const data = (p && p.payload) || {};
      if (data.probe_spoof) got.spoof += 1;
      else if (p.event === 'message' && data.body === stamp) got.message = data;
      else if (p.event === 'typing' && data.typing === true) got.typing = data;
    },
    other: (msg) => { if (msg.event === 'presence_state' || msg.event === 'presence_diff') got.presence += 1; },
  }));
  result(victimRoom === 'ok' ? 'ok' : 'FAIL', 'lt_sec_a', 'kontrol: anggota room bisa join kanal privat room:<id>', victimRoom, '');
  const victimUser = await joinStatus(() => victim.joinPrivate(`user:${victimId}`, {
    broadcast: (p) => {
      const data = (p && p.payload) || {};
      if (p.event === 'room_activity' && data.preview === stamp) got.activity += 1;
    },
  }));
  result(victimUser === 'ok' ? 'ok' : 'FAIL', 'lt_sec_a', 'kontrol: nasabah bisa join kanal privat user miliknya', victimUser, '');
  victim.push(roomTopic, 'presence', { type: 'presence', event: 'track', payload: { user_id: victimId } }, victim.ref);
  await sleepMs(1500);
  result(got.presence > 0 ? 'ok' : 'FAIL', 'lt_sec_a', 'kontrol: presence anggota tetap berjalan', got.presence, '');

  for (const event of SPOOFED) {
    victim.push(roomTopic, 'broadcast', {
      type: 'broadcast', event, payload: { probe_spoof: true, message_id: 'x', user_id: 'x', typing: true },
    }, victim.ref);
  }
  const restVictim = SPOOFED.map((event) => restBroadcast(__ENV.VICTIM_JWT, `room:${ROOM}`, event,
    { probe_spoof: true, message_id: 'x', user_id: 'x', typing: true }).status);
  const restAttacker = restBroadcast(__ENV.JWT, `room:${ROOM}`, 'message_hidden', { probe_spoof: true, message_id: 'x' });
  const restUser = restBroadcast(__ENV.VICTIM_JWT, `user:${victimId}`, 'room_activity', { probe_spoof: true });
  await sleepMs(3000);
  result(got.spoof === 0 ? 'ok' : 'FAIL', 'lt_sec_a',
    'anggota room tidak bisa mengirim event server (message, message_hidden, room_state, reaction, receipt, typing) ke room:<id>',
    `${restVictim.join(',')}/${got.spoof}`, 'WebSocket + REST broadcast, self: true');
  result(attackerBroadcast === 0 ? 'ok' : 'FAIL', 'nasabah', 'REST broadcast ke kanal privat room orang lain tidak sampai',
    `${restAttacker.status}/${attackerBroadcast}`, '');
  result(got.spoof === 0 && got.activity === 0 ? 'ok' : 'FAIL', 'lt_sec_a', 'klien tidak bisa menulis ke kanal user:<id>',
    `${restUser.status}`, '');

  const sent = rpc(__ENV.VICTIM_JWT, 'send_message', { p_room_id: ROOM, p_body: stamp });
  try {
    const row = JSON.parse(sent.body);
    sentId = (Array.isArray(row) ? row[0] : row).id || '';
  } catch (_) {
    sentId = '';
  }
  const typed = rpc(__ENV.VICTIM_JWT, 'send_typing', { p_room_id: ROOM, p_typing: true });
  await sleepMs(4000);
  result(sent.status === 200 && sentId ? 'ok' : 'FAIL', 'lt_sec_a', 'kontrol: anggota mengirim pesan', sent.status, '');
  result(got.message && got.message.room_id === ROOM && typeof got.message.body === 'string' ? 'ok' : 'FAIL', 'lt_sec_a',
    'kontrol: pesan baru sampai lewat broadcast server di room:<id>', got.message ? 'diterima' : 'tidak diterima', '');
  result(got.activity === 1 ? 'ok' : 'FAIL', 'lt_sec_a', 'kontrol: aktivitas room sampai di user:<id>', got.activity, '');
  result(typed.status === 200 && got.typing && got.typing.user_id === victimId ? 'ok' : 'FAIL', 'lt_sec_a',
    'typing lewat RPC membawa identitas dari JWT', `${typed.status}/${got.typing ? got.typing.user_id === victimId : 'tidak diterima'}`, '');

  let attackerChanges = 0;
  let victimChanges = 0;
  await joinStatus(() => attacker.joinTable('probe-messages-a', 'messages', `room_id=eq.${ROOM}`, {
    change: () => { attackerChanges += 1; },
  }));
  await joinStatus(() => victim.joinTable('probe-messages-v', 'messages', `room_id=eq.${ROOM}`, {
    change: () => { victimChanges += 1; },
  }));
  await sleepMs(2500);
  rpc(__ENV.VICTIM_JWT, 'send_message', { p_room_id: ROOM, p_body: `probe realtime ${Date.now()}` });
  await sleepMs(4000);
  result(victimChanges === 0 ? 'ok' : 'FAIL', 'lt_sec_a', 'pesan tidak lagi dikirim lewat postgres_changes (beban RLS per penerima)',
    victimChanges, '');
  result(attackerChanges === 0 ? 'ok' : 'FAIL', 'nasabah', 'postgres_changes messages room orang lain tidak terkirim', attackerChanges, '');
  result(attackerBroadcast === 0 ? 'ok' : 'FAIL', 'nasabah', 'broadcast kanal privat room/user orang lain tidak terkirim', attackerBroadcast, '');
  attacker.close();
  victim.close();
}
