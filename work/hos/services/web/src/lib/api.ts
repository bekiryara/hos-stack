export async function getHealth(): Promise<any> {
  const resp = await fetch('/api/v1/health', {
    headers: { Accept: 'application/json' },
    cache: 'no-store',
  });

  const text = await resp.text();
  let json: any = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }

  if (!resp.ok) {
    const err: any = new Error('Health request failed: ' + resp.status);
    err.status = resp.status;
    err.body = json;
    throw err;
  }

  return json;
}

export async function getWorlds(): Promise<any[]> {
  const resp = await fetch('/api/v1/worlds', {
    headers: { Accept: 'application/json' },
    cache: 'no-store',
  });

  const text = await resp.text();
  let json: any = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }

  if (!resp.ok) {
    const err: any = new Error('Worlds request failed: ' + resp.status);
    err.status = resp.status;
    err.body = json;
    throw err;
  }

  if (!Array.isArray(json)) {
    throw new Error('Expected array response from /api/v1/worlds');
  }

  return json;
}

async function fetchJson(path: string, opts?: { method?: string; headers?: Record<string, string>; body?: any }, token?: string) {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    ...(opts?.headers ?? {}),
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  const method = opts?.method ?? 'GET';
  const body = opts?.body;
  if (body !== undefined && body !== null) {
    headers['Content-Type'] = headers['Content-Type'] ?? 'application/json';
  }

  const resp = await fetch(path, {
    method,
    headers,
    body: body === undefined || body === null ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
    cache: 'no-store',
  });

  const text = await resp.text();
  let json: any = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }

  if (!resp.ok) {
    const err: any = new Error(`${method} ${path} failed: ${resp.status}`);
    err.status = resp.status;
    err.body = json;
    throw err;
  }

  return json;
}

export async function hosLogin(params: { tenantSlug?: string; admin?: boolean; email: string; password: string }) {
  return await fetchJson('/api/v1/auth/login', { method: 'POST', body: params });
}

export async function hosMe(token: string) {
  return await fetchJson('/api/v1/me', undefined, token);
}

export async function adminTenants(token: string) {
  return await fetchJson('/api/v1/admin/platform/tenants', undefined, token);
}

export async function adminUsers(token: string) {
  return await fetchJson('/api/v1/admin/platform/users', undefined, token);
}

export async function adminMemberships(token: string) {
  return await fetchJson('/api/v1/admin/platform/memberships', undefined, token);
}

export async function adminAudit(
  token: string,
  opts: { limit?: number; offset?: number; action?: string; actor?: string; tenant?: string; q?: string; from?: string; to?: string } = {}
) {
  const qs = new URLSearchParams();
  qs.set('limit', String(opts.limit ?? 50));
  qs.set('offset', String(opts.offset ?? 0));
  if (opts.action) qs.set('action', opts.action);
  if (opts.actor) qs.set('actor', opts.actor);
  if (opts.tenant) qs.set('tenant', opts.tenant);
  if (opts.q) qs.set('q', opts.q);
  if (opts.from) qs.set('from', opts.from);
  if (opts.to) qs.set('to', opts.to);
  return await fetchJson(`/api/v1/admin/platform/audit?${qs}`, undefined, token);
}

export async function adminOverview(token: string) {
  return await fetchJson('/api/v1/admin/platform/overview', undefined, token);
}

export async function adminActionCenter(token: string) {
  return await fetchJson('/api/v1/admin/platform/action-center', undefined, token);
}

export async function adminListings(
  token: string,
  opts: { status?: 'all' | 'draft' | 'published' | 'paused' | 'archived'; tenant_id?: string; q?: string; page?: number; per_page?: number } = {}
) {
  const qs = new URLSearchParams();
  qs.set('status', String(opts.status || 'all'));
  qs.set('page', String(opts.page ?? 1));
  qs.set('per_page', String(opts.per_page ?? 50));
  if (opts.tenant_id) qs.set('tenant_id', opts.tenant_id);
  if (opts.q) qs.set('q', opts.q);
  return await fetchJson(`/api/v1/admin/platform/listings?${qs}`, undefined, token);
}

export async function adminListingsOverview(token: string) {
  return await fetchJson('/api/v1/admin/platform/listings/overview', undefined, token);
}
