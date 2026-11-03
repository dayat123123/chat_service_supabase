import { WebSocket } from 'k6/websockets';

export const options = {
  vus: 1,
  iterations: 1,
  hosts: { [__ENV.DOMAIN]: __ENV.IP },
};

export default async function () {
  const total = Number(__ENV.CONNECTIONS || 30);
  const sockets = [];
  let opened = 0;
  let rejected = 0;
  await Promise.all(Array.from({ length: total }, () => new Promise((resolve) => {
    const ws = new WebSocket(`${__ENV.WS_URL}/realtime/v1/websocket?apikey=${__ENV.ANON_KEY}&vsn=1.0.0`);
    sockets.push(ws);
    const timer = setTimeout(() => { rejected += 1; resolve(); }, 8000);
    ws.onopen = () => { clearTimeout(timer); opened += 1; resolve(); };
    ws.onerror = () => { clearTimeout(timer); rejected += 1; resolve(); };
  })));
  console.log(`RESULT ${JSON.stringify({ total, opened, rejected })}`);
  sockets.forEach((ws) => { try { ws.close(); } catch (_) { return; } });
}
