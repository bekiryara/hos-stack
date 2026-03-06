import React, { useEffect, useState } from 'react';
import { adminAudit, adminTenants, adminUsers, hosLogin, hosMe } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';

export function AdminControlCenterPage() {
  const tokenStorageKey = 'hos_admin_token';
  const [token, setToken] = useState<string>(() => localStorage.getItem(tokenStorageKey) || '');
  const [tenantSlug, setTenantSlug] = useState<string>('');
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [authBusy, setAuthBusy] = useState(false);
  const [me, setMe] = useState<any>(null);
  const [adminOut, setAdminOut] = useState<any>(null);
  const [adminErr, setAdminErr] = useState<any>(null);

  useEffect(() => {
    try {
      localStorage.setItem(tokenStorageKey, token || '');
    } catch {}
  }, [token]);

  async function adminRefreshMe() {
    setAdminErr(null);
    setAdminOut(null);
    if (!token) {
      setAdminErr(new Error('Missing token'));
      return;
    }
    try {
      const m = await hosMe(token);
      setMe(m);
      setAdminOut(m);
    } catch (e: any) {
      setAdminErr(e);
    }
  }

  async function adminDoLogin() {
    setAdminErr(null);
    setAdminOut(null);
    setAuthBusy(true);
    try {
      const resp = await hosLogin({ tenantSlug: tenantSlug || undefined, email, password });
      const t = resp?.token || resp?.access_token || resp?.jwt;
      if (!t) throw new Error('Login succeeded but no token returned');
      setToken(String(t));
      const m = await hosMe(String(t));
      setMe(m);
      setAdminOut({ login: 'ok', me: m });
    } catch (e: any) {
      setAdminErr(e);
    } finally {
      setAuthBusy(false);
    }
  }

  async function adminLoadTenants() {
    setAdminErr(null);
    setAdminOut(null);
    try {
      setAdminOut(await adminTenants(token));
    } catch (e: any) {
      setAdminErr(e);
    }
  }

  async function adminLoadUsers() {
    setAdminErr(null);
    setAdminOut(null);
    try {
      setAdminOut(await adminUsers(token));
    } catch (e: any) {
      setAdminErr(e);
    }
  }

  async function adminLoadAudit() {
    setAdminErr(null);
    setAdminOut(null);
    try {
      setAdminOut(await adminAudit(token, 50));
    } catch (e: any) {
      setAdminErr(e);
    }
  }

  return (
    <AdminLayout title="Admin Control Center">
      <p className="hint">
        SSOT: Admin surface lives in H-OS only. Pazar must not expose <code>/admin</code>/<code>/panel</code>.
      </p>

      <div className="card">
        <div className="title">Auth (JWT)</div>
        <div style={{ display: 'grid', gap: '0.5rem', maxWidth: 520 }}>
          <label>
            Tenant slug (optional)
            <input value={tenantSlug} onChange={(e) => setTenantSlug(e.target.value)} placeholder="acme" />
          </label>
          <label>
            Email
            <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin@acme.com" />
          </label>
          <label>
            Password
            <input
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="********"
              type="password"
            />
          </label>
          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
            <button onClick={adminDoLogin} disabled={authBusy || !email || !password}>
              {authBusy ? 'Logging in...' : 'Login'}
            </button>
            <button onClick={adminRefreshMe} disabled={!token}>
              /v1/me
            </button>
          </div>
          <label>
            Token (stored in localStorage: <code>{tokenStorageKey}</code>)
            <textarea
              value={token}
              onChange={(e) => setToken(e.target.value)}
              placeholder="paste JWT here"
              rows={4}
              style={{ width: '100%' }}
            />
          </label>
          {me ? (
            <div style={{ fontSize: '0.9rem', color: '#666' }}>
              Logged in as: <code>{me?.email || me?.sub || 'unknown'}</code>
            </div>
          ) : null}
        </div>
      </div>

      <div className="card">
        <div className="title">Admin APIs (HOS)</div>
        <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
          <button onClick={adminLoadTenants} disabled={!token}>
            GET /v1/admin/tenants
          </button>
          <button onClick={adminLoadUsers} disabled={!token}>
            GET /v1/admin/users
          </button>
          <button onClick={adminLoadAudit} disabled={!token}>
            GET /v1/admin/audit
          </button>
        </div>
        {adminErr ? (
          <div className="card error" style={{ marginTop: '0.75rem' }}>
            <div className="title">Error</div>
            <pre>{JSON.stringify({ message: adminErr?.message, status: adminErr?.status, body: adminErr?.body }, null, 2)}</pre>
          </div>
        ) : null}
        {adminOut ? (
          <div style={{ marginTop: '0.75rem' }}>
            <pre>{JSON.stringify(adminOut, null, 2)}</pre>
          </div>
        ) : null}
      </div>
    </AdminLayout>
  );
}
