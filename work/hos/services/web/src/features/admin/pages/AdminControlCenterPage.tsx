import React, { useEffect, useState } from 'react';
import { hosLogin, hosMe } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';

export function AdminControlCenterPage() {
  const tokenStorageKey = 'hos_admin_token';
  const [token, setToken] = useState<string>(() => localStorage.getItem(tokenStorageKey) || '');
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
      const resp = await hosLogin({ email, password });
      const t = resp?.token || resp?.access_token || resp?.jwt;
      if (!t) throw new Error('Giris basarili ama token donmedi');
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
    <AdminLayout title="Yonetim Girisi">
      <p className="hint">
        Platform yonetimi tek adresten yapilir.
      </p>

      <div className="card">
        <div className="title">Giris</div>
        <div style={{ display: 'grid', gap: '0.5rem', maxWidth: 520 }}>
          <label>
            E-posta
            <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin@firma.com" autoComplete="username" />
          </label>
          <label>
            Sifre
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
              {authBusy ? 'Giris yapiliyor...' : 'Giris Yap'}
            </button>
            <button onClick={logout} disabled={!token || authBusy}>
              Cikis Yap
            </button>
          </div>
          {me ? (
            <div style={{ fontSize: '0.9rem', color: '#666' }}>
              Giris yapan: <code>{me?.email || me?.sub || 'bilinmiyor'}</code> ({me?.memberships_count ?? 0} uyelik)
            </div>
          ) : (
            <div style={{ fontSize: '0.9rem', color: '#9ca3af' }}>Aktif admin oturumu yok.</div>
          )}
          <div style={{ fontSize: '0.82rem', color: '#9ca3af' }}>
            Oturum tokeni <code>{tokenStorageKey}</code> anahtarinda tutulur.
          </div>
          {adminErr ? (
            <div className="card error" style={{ marginTop: '0.75rem' }}>
              <div className="title">Hata</div>
              <pre>{JSON.stringify({ message: adminErr?.message, status: adminErr?.status, body: adminErr?.body }, null, 2)}</pre>
            </div>
          ) : null}
        </div>
      </div>

      <div className="card">
        <div className="title">Hizli Erisim</div>
        <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
          <a href="/admin/dashboard">Sistem Durumu</a>
          <a href="/admin/users">Kullanicilar</a>
          <a href="/admin/audit">Denetim</a>
        </div>
      </div>
    </AdminLayout>
  );
}
