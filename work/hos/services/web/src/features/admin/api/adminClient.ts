import {
  adminActionCenter as apiAdminActionCenter,
  adminAudit as apiAdminAudit,
  adminMemberships as apiAdminMemberships,
  adminOverview as apiAdminOverview,
  adminUsers as apiAdminUsers,
  hosLogin,
  hosMe as apiHosMe
} from '../../../lib/api';
import { clearAdminSession } from '../session';

export { hosLogin };

function rethrowWithAuthHandling(error: any): never {
  if (error?.status === 401) {
    clearAdminSession();
    window.location.href = '/admin';
  }
  throw error;
}

export async function hosMe(token: string) {
  try {
    return await apiHosMe(token);
  } catch (error: any) {
    rethrowWithAuthHandling(error);
  }
}

export async function adminUsers(token: string) {
  try {
    return await apiAdminUsers(token);
  } catch (error: any) {
    rethrowWithAuthHandling(error);
  }
}

export async function adminMemberships(token: string) {
  try {
    return await apiAdminMemberships(token);
  } catch (error: any) {
    rethrowWithAuthHandling(error);
  }
}

export async function adminAudit(
  token: string,
  opts?: { limit?: number; offset?: number; action?: string; actor?: string; tenant?: string; q?: string; from?: string; to?: string }
) {
  try {
    return await apiAdminAudit(token, opts);
  } catch (error: any) {
    rethrowWithAuthHandling(error);
  }
}

export async function adminOverview(token: string) {
  try {
    return await apiAdminOverview(token);
  } catch (error: any) {
    rethrowWithAuthHandling(error);
  }
}

export async function adminActionCenter(token: string) {
  try {
    return await apiAdminActionCenter(token);
  } catch (error: any) {
    rethrowWithAuthHandling(error);
  }
}

export async function adminUpdateMembership(
  token: string,
  tenantId: string,
  userId: string,
  patch: { role?: 'member' | 'admin' | 'owner'; status?: 'active' | 'inactive' | 'suspended' }
) {
  const resp = await fetch(
    `/api/v1/admin/platform/memberships/${encodeURIComponent(tenantId)}/${encodeURIComponent(userId)}`,
    {
      method: 'PATCH',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(patch),
      cache: 'no-store',
    }
  );

  const text = await resp.text();
  let json: any = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }

  if (!resp.ok) {
    const err: any = new Error(`PATCH /api/v1/admin/platform/memberships/:tenantId/:userId failed: ${resp.status}`);
    err.status = resp.status;
    err.body = json;
    rethrowWithAuthHandling(err);
  }
  return json;
}

export async function adminMembershipLifecycle(
  token: string,
  tenantId: string,
  userId: string,
  action: 'deactivate' | 'delete'
) {
  const resp = await fetch(
    `/api/v1/admin/platform/memberships/${encodeURIComponent(tenantId)}/${encodeURIComponent(userId)}/lifecycle`,
    {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ action }),
      cache: 'no-store',
    }
  );

  const text = await resp.text();
  let json: any = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }

  if (!resp.ok) {
    const err: any = new Error(
      `POST /api/v1/admin/platform/memberships/:tenantId/:userId/lifecycle failed: ${resp.status}`
    );
    err.status = resp.status;
    err.body = json;
    rethrowWithAuthHandling(err);
  }
  return json;
}

export async function adminUpdateUserRole(token: string, userId: string, role: 'member' | 'admin' | 'owner') {
  const resp = await fetch(`/api/v1/admin/platform/users/${encodeURIComponent(userId)}/role`, {
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
    const err: any = new Error(`PATCH /api/v1/admin/platform/users/:id/role failed: ${resp.status}`);
    err.status = resp.status;
    err.body = json;
    rethrowWithAuthHandling(err);
  }
  return json;
}

export async function adminUserLifecycle(token: string, userId: string, action: 'deactivate' | 'delete') {
  const resp = await fetch(`/api/v1/admin/platform/users/${encodeURIComponent(userId)}/lifecycle`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ action }),
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
    const err: any = new Error(`POST /api/v1/admin/platform/users/:id/lifecycle failed: ${resp.status}`);
    err.status = resp.status;
    err.body = json;
    rethrowWithAuthHandling(err);
  }
  return json;
}
