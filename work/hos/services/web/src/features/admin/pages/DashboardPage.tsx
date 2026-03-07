import React from 'react';
import { AdminLayout } from '../layout/AdminLayout';
import { adminActionCenter, adminOverview } from '../api/adminClient';
import { trAdminError } from '../utils/opsSafety';

export function DashboardPage() {
  const [loading, setLoading] = React.useState(false);
  const [overview, setOverview] = React.useState<any>(null);
  const [actionCenter, setActionCenter] = React.useState<any>(null);
  const [error, setError] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      setOverview(null);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const [o, ac] = await Promise.all([adminOverview(token), adminActionCenter(token)]);
      setOverview(o);
      setActionCenter(ac);
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Sistem durumu alinamadi'));
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    void load();
  }, [load]);

  return (
    <AdminLayout title="Sistem Pano">
      <div className="card">
        <div className="title">Platform Ozeti</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.6rem' }}>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Toplam Firma</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{overview?.tenants_total ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Toplam Kullanici</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{overview?.users_total ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Aktif Uyelik</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{overview?.memberships_active ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Denetim (24s)</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{overview?.audit_events_24h ?? 0}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="title">Aksiyon Merkezi</div>
        <div style={{ marginBottom: '0.75rem' }}>
          <button onClick={load} disabled={loading}>
            {loading ? 'Yukleniyor...' : 'Yenile'}
          </button>
        </div>
        {error ? (
          <div className="card error">
            <div className="title">Hata</div>
            <pre>{error}</pre>
          </div>
        ) : null}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.6rem' }}>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Kritik Islem (24s)</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{actionCenter?.critical_events_24h ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Owner Riski Olan Firma</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{actionCenter?.owner_risk_tenants ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Kullanici Silme (24s)</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{actionCenter?.users_deleted_24h ?? 0}</div>
          </div>
        </div>

        <div style={{ marginTop: '0.75rem', display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
          <a href="/admin/worlds">Dunyalar</a>
          <a href="/admin/users">Kullanicilar</a>
          <a href="/admin/memberships">Uyelikler</a>
          <a href="/admin/audit">Denetim</a>
        </div>

        <div style={{ marginTop: '0.9rem' }}>
          <div style={{ fontWeight: 600, marginBottom: '0.5rem' }}>Son Kritik Islemler</div>
          {!Array.isArray(actionCenter?.latest_critical_events) || actionCenter.latest_critical_events.length === 0 ? (
            <p style={{ color: '#9ca3af', margin: 0 }}>Kritik kayit yok.</p>
          ) : (
            <div style={{ display: 'grid', gap: '0.5rem' }}>
              {actionCenter.latest_critical_events.map((row: any) => (
                <div key={row.id} className="card" style={{ padding: '0.6rem 0.7rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.75rem', flexWrap: 'wrap' }}>
                    <strong>{row.action || '-'}</strong>
                    <span style={{ color: '#9ca3af' }}>{row.created_at || '-'}</span>
                  </div>
                  <div style={{ fontSize: '0.9rem', marginTop: '0.35rem' }}>
                    islem yapan: <code>{row.actor_email || row.actor_user_id || '-'}</code>
                  </div>
                  <div style={{ fontSize: '0.9rem', marginTop: '0.25rem' }}>
                    firma: <code>{row.tenant_slug || row.tenant_id || '-'}</code>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </AdminLayout>
  );
}
