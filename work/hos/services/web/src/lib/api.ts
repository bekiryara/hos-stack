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

export async function adminAudit(token: string, limit: number = 50) {
  const qs = new URLSearchParams({ limit: String(limit) }).toString();
  return await fetchJson(`/api/v1/admin/platform/audit?${qs}`, undefined, token);
}

export async function adminOverview(token: string) {
  return await fetchJson('/api/v1/admin/platform/overview', undefined, token);
}
