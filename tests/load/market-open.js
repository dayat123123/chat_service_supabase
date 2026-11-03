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
const PRESENCE = __ENV.PRESENCE !== '0';

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

const timed = ['bridge_exchange', 'get_feed', 'get_feed_stock', 'get_trending', 'join_stock_room', 'get_messages', 'send_message',
  'create_post', 'get_notifications', 'get_notification_unread_count', 'get_client_config', 'mark_room_read', 'stock_watchers'];
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
  await api.rpc('get_messages', { p_room_id: roomId, p_limit: 30 });
  await api.rpc('mark_room_read', { p_room_id: roomId });

  let dropped = false;
  const rt = new Realtime(API, ANON, api.jwt, { onClose: () => { dropped = true; } });
  try {
    await rt.connect();
    connectTime.add(rt.connectMs);
  } catch (e) {
    wsFailed.add(1, { reason: String(e.message || e).slice(0, 40) });
    await sleepMs(3000);
    return;
  }
  const onChange = (data) => {
    if (!data || data.type !== 'INSERT' || !data.record) return;
    const m = stampRe.exec(data.record.body || '');
    if (!m) return;
    received.add(1);
    delivery.add(Date.now() - parseInt(m[1], 36));
  };
  try {
    const r1 = await rt.joinTable(`olt-messages-${vu}`, 'messages', `room_id=eq.${roomId}`, { change: onChange });
    joinTime.add(r1.joinMs, { channel: 'postgres_changes' });
    if (r1.status !== 'ok') joinFailed.add(1, { stage: 'postgres_changes' });
    const r2 = await rt.joinPrivate(`room:${roomId}`, {}, PRESENCE ? api.userId : '');
    joinTime.add(r2.joinMs, { channel: 'private' });
    if (r2.status !== 'ok') joinFailed.add(1, { stage: 'private' });
    if (PRESENCE && r2.status === 'ok') {
      rt.push(`realtime:room:${roomId}`, 'presence', { type: 'presence', event: 'track', payload: { user_id: api.userId } }, rt.ref);
    }
  } catch (e) {
    joinFailed.add(1, { stage: String(e.message || e).slice(0, 30) });
  }
  subscribed.add(1);
  const subscribedAt = new Date().toISOString();

  let nextSend = Date.now() + jitter(MSG_EVERY);
  let nextFeed = Date.now() + jitter(FEED_EVERY);
  let postAt = Math.random() < POST_PROB ? Date.now() + Math.random() * Math.max(5000, deadline - Date.now() - 10000) : Infinity;
  let notificationsRead = false;
  while (Date.now() < deadline && !dropped) {
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
    if (now >= postAt) {
      postAt = Infinity;
      const res = await api.rpc('create_post', { p_body: `${pick()} ${pick()} $${POST_CODE} ${pick()} sesi pagi ${vu}x${seq}`, p_sentiment: 'bullish' });
      if (res.status === 200) postsCreated.add(1);
    }
    await sleepMs(250);
  }
  if (dropped) wsDropped.add(1);
  const until = new Date().toISOString();
  await sleepMs(3000);
  const count = await api.rest('HEAD', `messages?room_id=eq.${roomId}&created_at=gte.${subscribedAt}&created_at=lt.${until}&body=like.*k*`, null,
    { name: 'count_messages', headers: { Prefer: 'count=exact' } });
  const range = (count.headers['Content-Range'] || '').split('/')[1];
  if (range && range !== '*') expected.add(Number(range));
  rt.close();
}

export function handleSummary(data) {
  const out = __ENV.SUMMARY || '/olt/results/k6-summary.json';
  return { [out]: JSON.stringify(data, null, 1), stdout: '' };
}
