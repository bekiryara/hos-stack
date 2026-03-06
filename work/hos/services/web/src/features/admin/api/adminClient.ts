import { adminAudit, adminTenants, adminUsers, hosLogin, hosMe } from '../../../lib/api';

export { adminAudit, adminTenants, adminUsers, hosLogin, hosMe };

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
