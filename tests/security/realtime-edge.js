import encoding from 'k6/encoding';
import { Realtime, sleepMs } from '../load/lib/realtime.js';

export const options = {
  vus: 1,
  iterations: 1,
  hosts: { [__ENV.DOMAIN]: __ENV.IP, [__ENV.CS_DOMAIN]: __ENV.IP },
};

const PUBLIC = `https://${__ENV.DOMAIN}:8443`;
const CS = `https://${__ENV.CS_DOMAIN}:8443`;
const ANON = __ENV.ANON_KEY;

function result(ok, check, status) {
  console.log(`RESULT ${JSON.stringify({ verdict: ok ? 'ok' : 'FAIL', check, status: String(status) })}`);
}

function subject(jwt) {
  try {
    return JSON.parse(encoding.b64decode(jwt.split('.')[1], 'rawurl', 's')).sub || '';
  } catch (_) {
    return '';
  }
}

async function socket(base, jwt, headers) {
  const rt = new Realtime(base, ANON, jwt, headers ? { headers } : {});
  await rt.connect();
  return rt;
}

async function joinPrivate(rt, topic) {
  const errors = [];
  let status;
  try {
    const reply = await rt.joinPrivate(topic, {
      system: (p) => { if (p && p.status === 'error') errors.push(p.message || 'error'); },
      error: (ev) => errors.push(ev),
    });
    status = reply.status || 'unknown';
    if (status !== 'ok' && reply.response && reply.response.reason) errors.push(reply.response.reason);
  } catch (e) {
    status = String(e.message || e);
  }
  await sleepMs(800);
  return { joined: status === 'ok' && errors.length === 0, status: `${status}${errors.length ? ` ${errors.join(',')}` : ''}` };
}

async function joinChanges(rt, name) {
  const system = [];
  let status;
  try {
    const reply = await rt.joinTable(name, 'posts', undefined, {
      system: (p) => { if (p && p.extension === 'postgres_changes') system.push(p.status); },
    });
    status = reply.status || 'unknown';
  } catch (e) {
    status = String(e.message || e);
  }
  for (let i = 0; i < 20 && system.length === 0; i++) await sleepMs(250);
  return { subscribed: status === 'ok' && system.includes('ok') && !system.includes('error'), status: `${status}/${system.join(',') || 'none'}` };
}

export default async function () {
  const staff = __ENV.STAFF_JWT;
  const customer = __ENV.CUST_JWT;
  const customerId = subject(customer);
  const sockets = [];
  const open = async (base, jwt, headers) => {
    const rt = await socket(base, jwt, headers);
    sockets.push(rt);
    return rt;
  };

  try {
    const csStaff = await open(CS, staff, { 'X-Olt-Edge': 'public' });
    let r = await joinPrivate(csStaff, 'cs:queue');
    result(r.joined, 'staf lewat domain CS (penanda public palsu dibuang) bisa join cs:queue', r.status);

    const pubStaff = await open(PUBLIC, staff);
    r = await joinPrivate(pubStaff, 'cs:queue');
    result(!r.joined, 'staf lewat domain publik tidak bisa join cs:queue (walau JWT yang sama sudah join di domain CS)', r.status);

    const spoofStaff = await open(PUBLIC, staff, { 'X-Olt-Edge': 'cs' });
    r = await joinPrivate(spoofStaff, 'cs:queue');
    result(!r.joined, 'staf lewat domain publik dengan X-Olt-Edge: cs palsu tetap ditolak', r.status);

    const c = await joinChanges(pubStaff, 'edge-staff-posts');
    result(!c.subscribed, 'staf tidak bisa berlangganan postgres_changes di domain publik', c.status);

    const pubCustomer = await open(PUBLIC, customer);
    r = await joinPrivate(pubCustomer, `user:${customerId}`);
    result(r.joined, 'kontrol: nasabah lewat domain publik tetap bisa join user:<id> miliknya', r.status);
    r = await joinPrivate(pubCustomer, 'online');
    result(!r.joined, 'topik online ditutup (0105)', r.status);
    const cc = await joinChanges(pubCustomer, 'edge-customer-posts');
    result(cc.subscribed, 'kontrol: nasabah lewat domain publik tetap bisa postgres_changes posts', cc.status);
  } catch (e) {
    result(false, 'probe realtime-edge selesai tanpa error', String(e.message || e));
  } finally {
    sockets.forEach((rt) => rt.close());
  }
}
