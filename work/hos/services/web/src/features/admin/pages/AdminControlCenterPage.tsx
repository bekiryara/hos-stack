import React, { useEffect, useState } from 'react';
import { hosLogin, hosMe } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';

export function AdminControlCenterPage() {
  const tokenStorageKey = 'hos_admin_token';
  const [token, setToken] = useState<string>(() => localStorage.getItem(tokenStorageKey) || '');
  const [tenantSlug, setTenantSlug] = useState<string>('');
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [authBusy, setAuthBusy] = useState(false);
  const [me, setMe] = useState<any>(null);
  const [adminErr, setAdminErr] = useState<any>(null);

  useEffect(() => {
    try {
      localStorage.setItem(tokenStorageKey, token || '');
    } catch {}
  }, [token]);

  useEffect(() => {
    if (!token) {
      setMe(null);
      return;
    }
    void adminRefreshMe();
  }, [token]);

  async function adminRefreshMe() {
    setAdminErr(null);
    if (!token) {
      setAdminErr(new Error('Missing token'));
      return;
    }
    try {
      const m = await hosMe(token);
      setMe(m);
    } catch (e: any) {
      setAdminErr(e);
    }
  }

  async function adminDoLogin() {
    setAdminErr(null);
    setAuthBusy(true);
    try {
      const resp = await hosLogin({ tenantSlug: tenantSlug || undefined, email, password });
      const t = resp?.token || resp?.access_token || resp?.jwt;
      if (!t) throw new Error('Login succeeded but no token returned');
      setToken(String(t));
      setPassword('');
    } catch (e: any) {
      setAdminErr(e);
    } finally {
      setAuthBusy(false);
    }
  }

  function logout() {
    setToken('');
    setMe(null);
    setAdminErr(null);
  }

  return (
    <AdminLayout title="Admin Control Center">
      <p className="hint">
        SSOT: Admin surface lives in H-OS only. Pazar must not expose <code>/admin</code>/<code>/panel</code>.
      </p>

      <div className="card">
        <div className="title">Admin Login</div>
        <div style={{ display: 'grid', gap: '0.5rem', maxWidth: 520 }}>
          <label>
            Tenant slug (optional)
            <input value={tenantSlug} onChange={(e) => setTenantSlug(e.target.value)} placeholder="acme" autoComplete="organization" />
          </label>
          <label>
            Email
            <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin@acme.com" autoComplete="username" />
          </label>
          <label>
            Password
            <input
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="********"
              type="password"
              autoComplete="current-password"
            />
          </label>
          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
            <button onClick={adminDoLogin} disabled={authBusy || !email || !password}>
              {authBusy ? 'Logging in...' : 'Login'}
            </button>
            <button onClick={adminRefreshMe} disabled={!token || authBusy}>
              Refresh Session
            </button>
            <button onClick={logout} disabled={!token || authBusy}>
              Logout
            </button>
          </div>
          {me ? (
            <div style={{ fontSize: '0.9rem', color: '#666' }}>
              Logged in as: <code>{me?.email || me?.sub || 'unknown'}</code> ({me?.memberships_count ?? 0} memberships)
            </div>
          ) : (
            <div style={{ fontSize: '0.9rem', color: '#9ca3af' }}>No active admin session.</div>
          )}
          <div style={{ fontSize: '0.82rem', color: '#9ca3af' }}>
            Session token is stored in <code>{tokenStorageKey}</code>.
          </div>
          {adminErr ? (
            <div className="card error" style={{ marginTop: '0.75rem' }}>
              <div className="title">Error</div>
              <pre>{JSON.stringify({ message: adminErr?.message, status: adminErr?.status, body: adminErr?.body }, null, 2)}</pre>
            </div>
          ) : null}
        </div>
      </div>

      <div className="card">
        <div className="title">Quick Access</div>
        <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
          <a href="/admin/tenants">Tenants</a>
          <a href="/admin/users">Users</a>
          <a href="/admin/memberships">Memberships</a>
          <a href="/admin/audit">Audit</a>
        </div>
      </div>
    </AdminLayout>
  );
}
