import http from 'k6/http';
import { Counter } from 'k6/metrics';

const RATE = Number(__ENV.RATE || 20);
const DURATION = __ENV.DURATION || '60s';
const BATCH = Number(__ENV.BATCH || 1);
const results = new Counter('notify_results');

export const options = {
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  thresholds: Object.assign({ 'http_req_duration{name:notify}': ['p(95)<2000'] },
    ...['queued', 'no_recipient', 'accepted', 'duplicate', 'invalid', 'inbox', 'http_429', 'http_401', 'http_503', 'http_500']
      .map((s) => ({ [`notify_results{status:${s}}`]: ['count>=0'] }))),
  scenarios: {
    notify: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: Math.max(10, RATE),
      maxVUs: Math.max(50, RATE * 4),
    },
  },
};

export default function () {
  const messages = Array.from({ length: BATCH }, (_, i) => ({
    id: `lt-${__ENV.RUN}-${__VU}-${__ITER}-${i}`,
    cust_id: `LTX${(__VU * 100000 + __ITER * 10 + i) % 9999999}`,
    kind: 'olt.trade',
    title: 'Order uji beban match',
    body: 'Beli 1 lot uji beban',
    channels: ['inbox'],
    ttl_seconds: 600,
  }));
  const res = http.post(`${__ENV.API}/integration/v1/notify/messages`, JSON.stringify({ messages }), {
    headers: { apikey: __ENV.ANON_KEY, Authorization: `Bearer ${__ENV.KEY}`, 'Content-Type': 'application/json' },
    tags: { name: 'notify' },
  });
  if (res.status === 200) {
    try {
      (res.json().results || []).forEach((r) => results.add(1, { status: r.status || 'unknown' }));
    } catch (_) {
      results.add(1, { status: 'bad_json' });
    }
  } else {
    results.add(1, { status: `http_${res.status}` });
  }
}

export function handleSummary(data) {
  return { [__ENV.SUMMARY]: JSON.stringify(data, null, 1), stdout: '' };
}
