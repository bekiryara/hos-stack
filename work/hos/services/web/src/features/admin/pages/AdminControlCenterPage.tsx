import React, { useEffect, useState } from 'react';
import { hosLogin, hosMe } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';
import { getAdminToken, setAdminSession } from '../session';

export function AdminControlCenterPage() {
  const [token, setToken] = useState<string>(() => getAdminToken());
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [authBusy, setAuthBusy] = useState(false);
  const [me, setMe] = useState<any>(null);
  const [adminErr, setAdminErr] = useState<any>(null);

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
      setAdminErr(new Error('Token bulunamadi'));
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
      const resp = await hosLogin({ admin: true, email, password });
      const t = resp?.token || resp?.access_token || resp?.jwt;
      if (!t) throw new Error('Giris basarili ama token donmedi');
      const tokenValue = String(t);
      setToken(tokenValue);
      setAdminSession(tokenValue, email);
      setPassword('');
      window.location.href = '/admin/dashboard';
    } catch (e: any) {
      setAdminErr(e);
    } finally {
      setAuthBusy(false);
    }
  }

  return (
    <AdminLayout title="Kontrol Merkezi">
      <p className="hint">
        Bu ekran sadece yonetim girisi icindir.
      </p>

      <div className="card" style={{ maxWidth: 680, padding: '1.25rem' }}>
        <div className="title">Oturum Islemleri</div>
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
              <pre>{JSON.stringify({ message: adminErr?.message, status: adminErr?.status, body: adminErr?.body }, null, 2)}</pre>
            </div>
          ) : null}
        </div>
      </div>
    </AdminLayout>
  );
}
