import React from 'react';
import { AdminLayout } from '../layout/AdminLayout';
import { adminActionCenter, adminListingsOverview, adminOverview } from '../api/adminClient';
import { trAdminError } from '../utils/opsSafety';

export function DashboardPage() {
  const [loading, setLoading] = React.useState(false);
  const [overview, setOverview] = React.useState<any>(null);
  const [listingOverview, setListingOverview] = React.useState<any>(null);
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
      const [o, lo, ac] = await Promise.all([adminOverview(token), adminListingsOverview(token), adminActionCenter(token)]);
      setOverview(o);
      setListingOverview(lo);
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
        <div className="title">Ilan Gostergeleri</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.6rem' }}>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Toplam Ilan</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{listingOverview?.total ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Yayinda</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{listingOverview?.published ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Durduruldu</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{listingOverview?.paused ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Taslak / Arsiv</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>
              {(listingOverview?.draft ?? 0)} / {(listingOverview?.archived ?? 0)}
            </div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Ilan Islem (24s)</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{listingOverview?.lifecycle_24h_total ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Yayin/Durdur/Arsiv/Sil (24s)</div>
            <div style={{ fontSize: '1rem', fontWeight: 700 }}>
              {(listingOverview?.lifecycle_24h_publish ?? 0)} / {(listingOverview?.lifecycle_24h_pause ?? 0)} / {(listingOverview?.lifecycle_24h_archive ?? 0)} / {(listingOverview?.lifecycle_24h_delete ?? 0)}
            </div>
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

      </div>
    </AdminLayout>
  );
}
