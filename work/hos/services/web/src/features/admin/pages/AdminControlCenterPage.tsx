import React, { useEffect, useState } from 'react';
import { hosLogin, hosMe } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';
import { getAdminToken, setAdminSession } from '../session';
import { trAdminError } from '../utils/opsSafety';

export function AdminControlCenterPage() {
  const search = new URLSearchParams(window.location.search);
  const nextPath = search.get('next') || '';
  const safeNextPath =
    nextPath.startsWith('/admin/') && nextPath !== '/admin/control-center'
      ? nextPath
      : '/admin/dashboard';
  const [token, setToken] = useState<string>(() => getAdminToken());
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [authBusy, setAuthBusy] = useState(false);
  const [me, setMe] = useState<any>(null);
  const [adminErr, setAdminErr] = useState<string | null>(null);

  useEffect(() => {
    setAdminSession(token, email || undefined);
  }, [token, email]);

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
      setAdminErr('Token bulunamadi');
      return;
    }
    try {
      const m = await hosMe(token);
      setMe(m);
    } catch (e: any) {
      setAdminErr(trAdminError(e?.body?.error || e?.message, 'Oturum bilgisi alinamadi.'));
    }
  }

  async function adminDoLogin() {
    setAdminErr(null);
    setAuthBusy(true);
    try {
      const resp = await hosLogin({ admin: true, email, password });
      const t = resp?.token || resp?.access_token || resp?.jwt;
      if (!t) throw new Error('Giris basarili ama token donmedi');
      const tokenValue = String(t);
      setToken(tokenValue);
      setAdminSession(tokenValue, email);
      setPassword('');
      window.location.href = safeNextPath;
    } catch (e: any) {
      setAdminErr(trAdminError(e?.body?.error || e?.message, 'Giris yapilamadi.'));
    } finally {
      setAuthBusy(false);
    }
  }

  return (
    <AdminLayout title="Admin Giris">
      <div
        style={{
          minHeight: 'calc(100vh - 220px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div className="card" style={{ width: '100%', maxWidth: 680, padding: '1.25rem' }}>
          <div className="title">Oturum Islemleri</div>
          <p className="hint" style={{ marginTop: 0 }}>
            Bu ekran sadece yonetim girisi icindir.
          </p>
          <div style={{ display: 'grid', gap: '1rem', maxWidth: 560 }}>
          <label>
            <div style={{ marginBottom: '0.35rem', color: '#d1d5db' }}>E-posta</div>
            <input
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !authBusy && email && password) {
                  e.preventDefault();
                  void adminDoLogin();
                }
              }}
              placeholder="admin@firma.com"
              autoComplete="username"
              style={{ width: '100%', minHeight: 42 }}
            />
          </label>
          <label>
            <div style={{ marginBottom: '0.35rem', color: '#d1d5db' }}>Sifre</div>
            <input
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !authBusy && email && password) {
                  e.preventDefault();
                  void adminDoLogin();
                }
              }}
              placeholder="********"
              type="password"
              autoComplete="current-password"
              style={{ width: '100%', minHeight: 42 }}
            />
          </label>
          <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
            <button onClick={adminDoLogin} disabled={authBusy || !email || !password}>
              {authBusy ? 'Giris yapiliyor...' : 'Giris Yap'}
            </button>
          </div>
          {me ? (
            <div style={{ fontSize: '0.92rem', color: '#9ca3af' }}>
              Giris yapan: <code>{me?.email || me?.sub || 'bilinmiyor'}</code> ({me?.memberships_count ?? 0} uyelik)
            </div>
          ) : (
            <div style={{ fontSize: '0.9rem', color: '#9ca3af' }}>Aktif admin oturumu yok.</div>
          )}
          {adminErr ? (
            <div className="card error" style={{ marginTop: '0.75rem' }}>
              <div className="title">Hata</div>
              <pre>{adminErr}</pre>
            </div>
          ) : null}
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}
