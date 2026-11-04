import http from 'k6/http';
import { Counter } from 'k6/metrics';

export const rateLimited = new Counter('rate_limited');
export const apiErrors = new Counter('api_errors');
export const poolTimeouts = new Counter('pgrst003');

export class Api {
  constructor(base, anon, ip) {
    this.base = base;
    this.anon = anon;
    this.ip = ip;
    this.jwt = null;
  }

  headers(extra = {}) {
    const h = { apikey: this.anon, 'Content-Type': 'application/json', 'X-Forwarded-For': this.ip };
    if (this.jwt) h.Authorization = `Bearer ${this.jwt}`;
    return Object.assign(h, extra);
  }

  track(res, name) {
    if (res.status === 429 || (res.body && String(res.body).includes('rate_limited'))) rateLimited.add(1, { name });
    else if (res.status >= 400 || res.status === 0) apiErrors.add(1, { name, status: String(res.status) });
    if (res.status === 504 && res.body && String(res.body).includes('PGRST003')) poolTimeouts.add(1, { name });
    return res;
  }

  async exchange(socialToken) {
    const res = this.track(await http.asyncRequest('POST', `${this.base}/bridge/v1/exchange`, JSON.stringify({ token: socialToken }), {
      headers: this.headers(), tags: { name: 'bridge_exchange' },
    }), 'bridge_exchange');
    if (res.status === 200) {
      const body = res.json();
      this.jwt = body.access_token;
      this.userId = body.user && body.user.id;
    }
    return res;
  }

  async rpc(fn, args = {}, opts = {}) {
    const name = opts.name || fn;
    const params = { headers: this.headers(opts.headers || {}), tags: Object.assign({ name }, opts.tags || {}) };
    const res = opts.get
      ? await http.asyncRequest('GET', `${this.base}/rest/v1/rpc/${fn}?${Object.entries(args).map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&')}`, null, params)
      : await http.asyncRequest('POST', `${this.base}/rest/v1/rpc/${fn}`, JSON.stringify(args), params);
    return this.track(res, name);
  }

  async rest(method, path, body, opts = {}) {
    const name = opts.name || path.split('?')[0];
    const res = await http.asyncRequest(method, `${this.base}/rest/v1/${path}`, body ? JSON.stringify(body) : null, {
      headers: this.headers(opts.headers || {}), tags: { name },
    });
    return this.track(res, name);
  }
}

export function json(res, fallback = null) {
  try {
    return res.json();
  } catch (_) {
    return fallback;
  }
}
