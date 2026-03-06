import { adminAudit, adminTenants, adminUsers, hosLogin, hosMe } from '../../../lib/api';

export { adminAudit, adminTenants, adminUsers, hosLogin, hosMe };

export async function adminMemberships(token: string) {
  const resp = await fetch('/api/v1/admin/memberships', {
    method: 'GET',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
    },
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
    const err: any = new Error(`GET /api/v1/admin/memberships failed: ${resp.status}`);
    err.status = resp.status;
    err.body = json;
    throw err;
  }
  return json;
}

export async function adminUpdateMembership(
  token: string,
  userId: string,
  payload: { role?: 'member' | 'admin' | 'owner'; status?: 'active' | 'inactive' | 'suspended' }
) {
  const resp = await fetch(`/api/v1/admin/memberships/${encodeURIComponent(userId)}`, {
    method: 'PATCH',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
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
    const err: any = new Error(`PATCH /api/v1/admin/memberships/:userId failed: ${resp.status}`);
    err.status = resp.status;
    err.body = json;
    throw err;
  }
  return json;
}

export async function adminMyMemberships(token: string) {
  const resp = await fetch('/api/v1/me/memberships', {
    method: 'GET',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
    },
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
    const err: any = new Error(`GET /api/v1/me/memberships failed: ${resp.status}`);
    err.status = resp.status;
    err.body = json;
    throw err;
  }
  return json;
}

export async function adminUpdateUserRole(token: string, userId: string, role: 'member' | 'admin' | 'owner') {
  const resp = await fetch(`/api/v1/admin/users/${encodeURIComponent(userId)}/role`, {
    method: 'PATCH',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ role }),
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
    const err: any = new Error(`PATCH /api/v1/admin/users/:id/role failed: ${resp.status}`);
    err.status = resp.status;
    err.body = json;
    throw err;
  }
  return json;
}
