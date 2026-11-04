import { WebSocket } from 'k6/websockets';

export class Realtime {
  constructor(api, apikey, jwt, opts = {}) {
    this.url = `${api.replace(/^http/, 'ws')}/realtime/v1/websocket?apikey=${apikey}&vsn=1.0.0`;
    this.jwt = jwt;
    this.ref = 0;
    this.pending = {};
    this.channels = {};
    this.onClose = opts.onClose || (() => {});
    this.onError = opts.onError || (() => {});
    this.heartbeatMs = opts.heartbeatMs || 25000;
    this.open = false;
    this.closed = false;
    this.headers = opts.headers || null;
  }

  connect(timeoutMs = 10000) {
    return new Promise((resolve, reject) => {
      const started = Date.now();
      const ws = this.headers ? new WebSocket(this.url, null, { headers: this.headers }) : new WebSocket(this.url);
      this.ws = ws;
      const timer = setTimeout(() => reject(new Error('ws_connect_timeout')), timeoutMs);
      ws.onopen = () => {
        clearTimeout(timer);
        this.open = true;
        this.connectMs = Date.now() - started;
        this.hb = setInterval(() => this.push('phoenix', 'heartbeat', {}), this.heartbeatMs);
        resolve(this);
      };
      ws.onmessage = (e) => this.dispatch(e.data);
      ws.onerror = (e) => {
        clearTimeout(timer);
        this.onError(e);
        if (!this.open) reject(new Error(`ws_error ${e && e.error ? e.error : ''}`));
      };
      ws.onclose = () => {
        this.open = false;
        if (this.hb) clearInterval(this.hb);
        Object.values(this.pending).forEach((p) => p.reject(new Error('ws_closed')));
        this.pending = {};
        if (!this.closed) this.onClose();
      };
    });
  }

  push(topic, event, payload, joinRef) {
    const ref = String(++this.ref);
    if (this.open) this.ws.send(JSON.stringify({ topic, event, payload, ref, join_ref: joinRef || null }));
    return ref;
  }

  request(topic, event, payload, timeoutMs = 10000, joinRef) {
    return new Promise((resolve, reject) => {
      if (!this.open) {
        reject(new Error('ws_not_open'));
        return;
      }
      const ref = String(this.ref + 1);
      const timer = setTimeout(() => {
        delete this.pending[ref];
        reject(new Error('reply_timeout'));
      }, timeoutMs);
      this.pending[ref] = {
        resolve: (v) => { clearTimeout(timer); resolve(v); },
        reject: (e) => { clearTimeout(timer); reject(e); },
      };
      this.push(topic, event, payload, joinRef || ref);
    });
  }

  join(name, config, handlers = {}, timeoutMs = 10000) {
    const topic = `realtime:${name}`;
    this.channels[topic] = handlers;
    const started = Date.now();
    return this.request(topic, 'phx_join', { config, access_token: this.jwt }, timeoutMs).then((reply) => {
      reply.joinMs = Date.now() - started;
      return reply;
    });
  }

  joinTable(name, table, filter, handlers = {}) {
    return this.join(name, {
      broadcast: { self: false, ack: false },
      presence: { key: '' },
      postgres_changes: [{ event: '*', schema: 'public', table, filter }],
      private: false,
    }, handlers);
  }

  joinPrivate(name, handlers = {}, presenceKey = '') {
    return this.join(name, {
      broadcast: { self: false, ack: false },
      presence: { key: presenceKey, enabled: presenceKey !== '' },
      postgres_changes: [],
      private: true,
    }, handlers);
  }

  dispatch(raw) {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch (_) {
      return;
    }
    if (msg.event === 'phx_reply' && this.pending[msg.ref]) {
      const p = this.pending[msg.ref];
      delete this.pending[msg.ref];
      p.resolve(msg.payload || {});
      return;
    }
    const h = this.channels[msg.topic];
    if (!h) return;
    if (msg.event === 'postgres_changes' && h.change) h.change(msg.payload && msg.payload.data, msg);
    else if (msg.event === 'broadcast' && h.broadcast) h.broadcast(msg.payload, msg);
    else if (msg.event === 'system' && h.system) h.system(msg.payload, msg);
    else if ((msg.event === 'phx_error' || msg.event === 'phx_close') && h.error) h.error(msg.event, msg.payload);
    else if (h.other) h.other(msg);
  }

  close() {
    this.closed = true;
    if (this.hb) clearInterval(this.hb);
    try {
      this.ws.close();
    } catch (_) {
      return;
    }
  }
}

export function sleepMs(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
