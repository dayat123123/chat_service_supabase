import { SharedArray } from 'k6/data';
import exec from 'k6/execution';
import { Counter, Trend } from 'k6/metrics';
import { Api, json } from './lib/api.js';
import { Realtime, sleepMs } from './lib/realtime.js';

const users = new SharedArray('users', () => JSON.parse(open(__ENV.USERS)));
const API = __ENV.API;
const ANON = __ENV.ANON_KEY;
const VUS = Number(__ENV.VUS || 50);
const RAMP = Number(__ENV.RAMP || 30);
const HOLD = Number(__ENV.HOLD || 120);
const ROOM_CODE = __ENV.ROOM_CODE || 'LTHOT';
const POST_CODE = __ENV.POST_CODE || 'LTPOST';
const MSG_EVERY = Number(__ENV.MSG_EVERY || 20);
const FEED_EVERY = Number(__ENV.FEED_EVERY || 45);
const POST_PROB = Number(__ENV.POST_PROB || 0.2);
const GAP_EVERY = Number(__ENV.GAP_EVERY || 45);
const GAP_OVERLAP = Number(__ENV.GAP_OVERLAP || 10);
const GAP_PAGES = Number(__ENV.GAP_PAGES || 5);
const GAP_IDS = __ENV.GAP_IDS !== '0';
const ID_PAGE = 1000;
const ID_BATCH = 100;
const PAGE_SIZE = 30;
const RECONNECT_JITTER = Number(__ENV.RECONNECT_JITTER || 5);
const GAP_RECHECK = Number(__ENV.GAP_RECHECK || 5);
const ZERO_ID = '00000000-0000-0000-0000-000000000000';
const PRESENCE = __ENV.PRESENCE !== '0';
const RECONNECT = __ENV.RECONNECT !== '0';
const END_SPREAD = Number(__ENV.END_SPREAD || 10);

const delivery = new Trend('rt_delivery_ms', true);
const joinTime = new Trend('rt_join_ms', true);
const connectTime = new Trend('ws_connect_ms', true);
const received = new Counter('rt_messages_received');
const sent = new Counter('msg_sent');
const sendFailed = new Counter('msg_send_failed');
const wsFailed = new Counter('ws_failed');
const wsDropped = new Counter('ws_dropped');
const joinFailed = new Counter('rt_join_failed');
const loginFailed = new Counter('login_failed');
const sessions = new Counter('sessions');
const subscribed = new Counter('rt_subscribed');
const postsCreated = new Counter('posts_created');
const expected = new Counter('rt_expected');
const receivedWindow = new Counter('rt_recv_window');
const gapOnly = new Counter('rt_gap_only');
const gapFetched = new Counter('rt_gap_rows');
const gapRuns = new Counter('gap_runs');
const gapTooLong = new Counter('gap_too_long');
const gapFailed = new Counter('gap_failed');
const reconnected = new Counter('ws_reconnected');
const countFailed = new Counter('count_failed');

const timed = ['bridge_exchange', 'get_feed', 'get_feed_stock', 'get_trending', 'join_stock_room', 'get_messages', 'send_message',
  'create_post', 'get_notifications', 'get_notification_unread_count', 'get_client_config', 'mark_room_read', 'stock_watchers',
  'get_message_ids', 'get_messages_by_ids', 'get_messages_gap', 'get_messages_reload'];
const thresholds = { rt_delivery_ms: ['p(95)<3000'], http_req_failed: ['rate<0.01'] };
timed.forEach((n) => { thresholds[`http_req_duration{name:${n}}`] = ['p(95)<2000']; });

export const options = {
  discardResponseBodies: false,
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  thresholds,
  scenarios: {
    customers: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: `${RAMP}s`, target: VUS },
        { duration: `${HOLD}s`, target: VUS },
      ],
      gracefulRampDown: '20s',
      gracefulStop: '30s',
    },
  },
};

const words = ['buka', 'antre', 'beli', 'naik', 'turun', 'volume', 'tebal', 'tipis', 'bid', 'offer', 'sabar', 'target',
  'support', 'resist', 'pantau', 'santai', 'hijau', 'merah', 'ramai', 'sepi', 'akumulasi', 'distribusi', 'koreksi', 'pantul'];
const pick = () => words[Math.floor(Math.random() * words.length)];
const jitter = (s) => s * 1000 * (0.5 + Math.random());
const stampRe = /\bk([0-9a-z]{8,9})\b/;
let seq = 0;

export default async function () {
  const vu = exec.vu.idInTest;
  const user = users[(vu - 1) % users.length];
  const deadline = exec.scenario.startTime + (RAMP + HOLD) * 1000;
  if (Date.now() > deadline - 5000) {
    await sleepMs(Math.max(0, deadline - Date.now()) + 1000);
    return;
  }
  const api = new Api(API, ANON, user.ip);
  sessions.add(1);

  const ex = await api.exchange(user.token);
  if (ex.status !== 200) {
    loginFailed.add(1, { status: String(ex.status) });
    await sleepMs(5000);
    return;
  }
  await api.rpc('get_client_config', { p_platform: 'android', p_app_version: '1.3.0' });
  await api.rpc('get_feed', { p_scope: 'global', p_limit: 20 });
  await api.rpc('get_trending', { p_window: '24h' });
  await api.rpc('get_notification_unread_count', {});
  const joined = await api.rpc('join_stock_room', { p_stock_code: ROOM_CODE });
  const roomId = json(joined);
  if (joined.status !== 200 || typeof roomId !== 'string') {
    joinFailed.add(1, { stage: 'rpc' });
    await sleepMs(5000);
    return;
  }
  await api.rest('POST', 'stock_watchers', { user_id: api.userId, stock_code: ROOM_CODE },
    { name: 'stock_watchers', headers: { Prefer: 'resolution=ignore-duplicates,return=minimal' } });
  const first = await api.rpc('get_messages', { p_room_id: roomId, p_limit: PAGE_SIZE });
  const firstRows = json(first, []);
  await api.rpc('mark_room_read', { p_room_id: roomId });

  let dropped = false;
  let rt = new Realtime(API, ANON, api.jwt, { onClose: () => { dropped = true; } });
  try {
    await rt.connect();
    connectTime.add(rt.connectMs);
  } catch (e) {
    wsFailed.add(1, { reason: String(e.message || e).slice(0, 40) });
    await sleepMs(3000);
    return;
  }
  const rtSeen = new Map();
  const gapSeen = new Map();
  const known = new Set();
  const later = (a, b) => (b && (!a || b > a) ? b : a);
  const newestCursor = (rows) => rows.reduce((acc, row) => later(acc, row && row.cursor), '');
  const oldestCursor = (rows) => rows.reduce((acc, row) => (row && row.cursor && (!acc || row.cursor < acc) ? row.cursor : acc), '');
  const rows0 = Array.isArray(firstRows) ? firstRows : [];
  rows0.forEach((row) => { if (row && row.id) known.add(row.id); });
  let horizon = newestCursor(rows0) || `1970-01-01T00:00:00.000Z|${ZERO_ID}`;
  const floor = oldestCursor(rows0);
  const onMessage = (msg) => {
    if (!msg || msg.event !== 'message' || !msg.payload) return;
    const row = msg.payload;
    const at = Date.parse(row.created_at || '') || 0;
    if (row.id) known.add(row.id);
    const m = stampRe.exec(row.body || '');
    if (!m || row.edited_at || row.is_deleted) return;
    received.add(1);
    if (row.id) rtSeen.set(row.id, at);
    delivery.add(Date.now() - parseInt(m[1], 36));
  };
  const keep = (rows) => {
    gapFetched.add(rows.length);
    for (const row of rows) {
      if (!row || !row.id) continue;
      known.add(row.id);
      if (stampRe.test(row.body || '') && !rtSeen.has(row.id)) gapSeen.set(row.id, Date.parse(row.created_at || '') || 0);
    }
  };
  const gapStart = () => {
    const at = Date.parse(horizon.split('|')[0]);
    const back = `${new Date(at - GAP_OVERLAP * 1000).toISOString()}|${ZERO_ID}`;
    return floor && floor > back ? floor : back;
  };
  const reloadLatest = async (kind) => {
    gapTooLong.add(1, { kind });
    const res = await api.rpc('get_messages', { p_room_id: roomId, p_limit: PAGE_SIZE }, { name: 'get_messages_reload', tags: { gap: kind } });
    const rows = json(res);
    if (res.status !== 200 || !Array.isArray(rows)) return false;
    keep(rows);
    horizon = later(horizon, newestCursor(rows));
    return true;
  };
  const byIds = async (kind) => {
    const ids = [];
    let reached = horizon;
    let cursor = gapStart();
    for (let page = 0; ; page++) {
      if (page === GAP_PAGES) return reloadLatest(kind);
      const res = await api.rpc('get_message_ids', { p_room_id: roomId, p_after: cursor, p_limit: ID_PAGE },
        { name: 'get_message_ids', tags: { gap: kind } });
      const body = json(res);
      if (res.status !== 200 || !body || !Array.isArray(body.ids)) return false;
      ids.push(...body.ids);
      reached = later(reached, body.last);
      if (!body.more || !body.last) break;
      cursor = body.last;
    }
    const missing = [...new Set(ids)].filter((id) => !known.has(id));
    if (missing.length > GAP_PAGES * ID_BATCH) return reloadLatest(kind);
    for (let i = 0; i < missing.length; i += ID_BATCH) {
      const res = await api.rpc('get_messages_by_ids', { p_room_id: roomId, p_ids: missing.slice(i, i + ID_BATCH) },
        { name: 'get_messages_by_ids', tags: { gap: kind } });
      const rows = json(res);
      if (res.status !== 200 || !Array.isArray(rows)) return false;
      keep(rows);
    }
    horizon = reached;
    return true;
  };
  const byPages = async (kind) => {
    let reached = horizon;
    let cursor = gapStart();
    for (let page = 0; cursor; page++) {
      if (page === GAP_PAGES) return reloadLatest(kind);
      const res = await api.rpc('get_messages', { p_room_id: roomId, p_after: cursor, p_limit: 100 }, { name: 'get_messages_gap', tags: { gap: kind } });
      const rows = json(res);
      if (res.status !== 200 || !Array.isArray(rows)) return false;
      keep(rows);
      reached = later(reached, newestCursor(rows));
      cursor = rows.length === 100 ? rows[rows.length - 1].cursor : '';
    }
    horizon = reached;
    return true;
  };
  const fillGap = async (kind) => {
    gapRuns.add(1, { kind });
    let ok = false;
    try {
      ok = await (GAP_IDS ? byIds(kind) : byPages(kind));
    } catch (e) {
      ok = false;
    }
    if (!ok) gapFailed.add(1, { kind });
  };
  const joinRoom = async () => {
    try {
      const r2 = await rt.joinPrivate(`room:${roomId}`, { broadcast: onMessage }, PRESENCE ? api.userId : '');
      joinTime.add(r2.joinMs, { channel: 'private' });
      if (r2.status !== 'ok') {
        joinFailed.add(1, { stage: 'private' });
        return false;
      }
      if (PRESENCE) {
        rt.push(`realtime:room:${roomId}`, 'presence', { type: 'presence', event: 'track', payload: { user_id: api.userId } }, rt.ref);
      }
      return true;
    } catch (e) {
      joinFailed.add(1, { stage: String(e.message || e).slice(0, 30) });
      return false;
    }
  };
  await joinRoom();
  subscribed.add(1);
  const subscribedAt = new Date().toISOString();
  await fillGap('join');
  let gapFirst = Infinity;
  let gapSecond = Infinity;
  const reconnect = async () => {
    wsDropped.add(1);
    let wait = 1000;
    while (Date.now() < deadline - 2000) {
      await sleepMs(wait + Math.random() * 1000);
      wait = Math.min(wait * 2, 8000);
      dropped = false;
      rt = new Realtime(API, ANON, api.jwt, { onClose: () => { dropped = true; } });
      try {
        await rt.connect();
      } catch (e) {
        wsFailed.add(1, { reason: 'reconnect' });
        rt.close();
        continue;
      }
      if (await joinRoom()) {
        reconnected.add(1);
        const delay = RECONNECT_JITTER * 1000 * Math.random();
        gapFirst = Date.now() + delay;
        gapSecond = GAP_RECHECK > 0 ? gapFirst + GAP_RECHECK * 1000 * (1 + Math.random()) : Infinity;
        return true;
      }
      rt.close();
    }
    return false;
  };

  let nextSend = Date.now() + jitter(MSG_EVERY);
  let nextFeed = Date.now() + jitter(FEED_EVERY);
  const gapInterval = () => GAP_EVERY * 1000 * (0.75 + Math.random() * 0.5);
  let nextGap = GAP_EVERY > 0 ? Date.now() + gapInterval() : Infinity;
  let postAt = Math.random() < POST_PROB ? Date.now() + Math.random() * Math.max(5000, deadline - Date.now() - 10000) : Infinity;
  let notificationsRead = false;
  let gaveUp = false;
  while (Date.now() < deadline && !gaveUp) {
    if (dropped) {
      if (!RECONNECT || !(await reconnect())) gaveUp = true;
      continue;
    }
    const now = Date.now();
    if (now >= nextSend) {
      nextSend = now + jitter(MSG_EVERY);
      seq += 1;
      const body = `${pick()} ${pick()} ${pick()} ${vu}x${seq} k${Date.now().toString(36)}`;
      const res = await api.rpc('send_message', { p_room_id: roomId, p_body: body });
      if (res.status === 200) sent.add(1); else sendFailed.add(1, { status: String(res.status) });
    }
    if (now >= nextFeed) {
      nextFeed = now + jitter(FEED_EVERY);
      await api.rpc('get_feed', { p_scope: 'stock', p_stock_code: ROOM_CODE, p_limit: 20 }, { name: 'get_feed_stock' });
      await api.rpc('get_notification_unread_count', {});
      if (!notificationsRead) {
        notificationsRead = true;
        await api.rpc('get_notifications', { p_limit: 30 });
      }
    }
    if (now >= nextGap) {
      nextGap = now + gapInterval();
      await fillGap('periodic');
    }
    if (now >= gapFirst) {
      gapFirst = Infinity;
      await fillGap('reconnect');
    }
    if (now >= gapSecond) {
      gapSecond = Infinity;
      await fillGap('recheck');
    }
    if (now >= postAt) {
      postAt = Infinity;
      const res = await api.rpc('create_post', { p_body: `${pick()} ${pick()} $${POST_CODE} ${pick()} sesi pagi ${vu}x${seq}`, p_sentiment: 'bullish' });
      if (res.status === 200) postsCreated.add(1);
    }
    await sleepMs(250);
  }
  if (gaveUp && !RECONNECT) wsDropped.add(1);
  const until = new Date().toISOString();
  await sleepMs(3000 + Math.random() * END_SPREAD * 1000);
  await fillGap('final');
  const from = Date.parse(subscribedAt);
  const to = Date.parse(until);
  const inWindow = (at) => at >= from && at < to;
  let rtWin = 0;
  rtSeen.forEach((at) => { if (inWindow(at)) rtWin += 1; });
  let gapWin = 0;
  gapSeen.forEach((at, id) => { if (!rtSeen.has(id) && inWindow(at)) gapWin += 1; });
  const count = await api.rest('HEAD', `messages?room_id=eq.${roomId}&created_at=gte.${subscribedAt}&created_at=lt.${until}&body=like.*k*`, null,
    { name: 'count_messages', headers: { Prefer: 'count=exact' } });
  const range = (count.headers['Content-Range'] || '').split('/')[1];
  if (count.status >= 200 && count.status < 300 && range && range !== '*') {
    expected.add(Number(range));
    receivedWindow.add(rtWin);
    gapOnly.add(gapWin);
  } else {
    countFailed.add(1, { status: String(count.status) });
  }
  rt.close();
}

export function handleSummary(data) {
  const out = __ENV.SUMMARY || '/olt/results/k6-summary.json';
  return { [out]: JSON.stringify(data, null, 1), stdout: '' };
}
