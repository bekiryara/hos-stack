import React from 'react';
import { getWorlds } from '../../../lib/api';
import { adminOverview } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';
import { trAdminError } from '../utils/opsSafety';

export function WorldsPage() {
  const [loading, setLoading] = React.useState(false);
  const [worlds, setWorlds] = React.useState<any[]>([]);
  const [overview, setOverview] = React.useState<any>(null);
  const [error, setError] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      setWorlds([]);
      setOverview(null);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const [o, w] = await Promise.all([adminOverview(token), getWorlds()]);
      setOverview(o);
      setWorlds(Array.isArray(w) ? w : []);
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Dunya verileri alinamadi'));
      setWorlds([]);
      setOverview(null);
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    void load();
  }, [load]);

  const summary = React.useMemo(() => {
    const total = worlds.length;
    const online = worlds.filter((w: any) => String(w?.availability || '').toUpperCase() === 'ONLINE').length;
    const disabled = worlds.filter((w: any) => String(w?.availability || '').toUpperCase() === 'DISABLED').length;
    const other = Math.max(0, total - online - disabled);
    return { total, online, disabled, other };
  }, [worlds]);

  return (
    <AdminLayout title="Dunyalar">
      <div className="card">
        <div className="title">Dunya Ozeti</div>
        <div style={{ marginBottom: '0.75rem' }}>
          <button onClick={load} disabled={loading}>
            {loading ? 'Yukleniyor...' : 'Yenile'}
          </button>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: '0.6rem' }}>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Toplam Dunya</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{summary.total}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>ONLINE</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{summary.online}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>DISABLED</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{summary.disabled}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Diger</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 700 }}>{summary.other}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="title">Platform Gosterge</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: '0.6rem' }}>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Toplam Firma</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{overview?.tenants_total ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Toplam Kullanici</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{overview?.users_total ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Aktif Uyelik</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{overview?.memberships_active ?? 0}</div>
          </div>
          <div className="card" style={{ padding: '0.75rem' }}>
            <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>Denetim (24s)</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{overview?.audit_events_24h ?? 0}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="title">Dunya Listesi</div>
        {error ? (
          <div className="card error">
            <div className="title">Hata</div>
            <pre>{String(error)}</pre>
          </div>
        ) : null}
        {!error && worlds.length === 0 ? <p>Dunya kaydi bulunamadi.</p> : null}
        {worlds.length > 0 ? (
          <div style={{ display: 'grid', gap: '0.55rem' }}>
            {worlds.map((world: any) => {
              const availability = String(world?.availability || '-').toUpperCase();
              const availabilityColor =
                availability === 'ONLINE' ? '#34d399' : availability === 'DISABLED' ? '#f87171' : '#fbbf24';
              return (
                <div key={world.world_key} className="card" style={{ padding: '0.7rem 0.8rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '0.6rem', flexWrap: 'wrap' }}>
                    <strong style={{ fontSize: '1rem' }}>{world.world_key || '-'}</strong>
                    <span
                      style={{
                        border: `1px solid ${availabilityColor}`,
                        color: availabilityColor,
                        borderRadius: 999,
                        padding: '0.15rem 0.55rem',
                        fontSize: '0.8rem',
                        fontWeight: 600,
                      }}
                    >
                      {availability}
                    </span>
                  </div>
                  <div style={{ marginTop: '0.35rem', color: '#9ca3af', fontSize: '0.9rem' }}>
                    Faz: <code>{world.phase || '-'}</code> | Versiyon: <code>{world.version || '-'}</code>
                  </div>
                </div>
              );
            })}
          </div>
        ) : null}
      </div>
    </AdminLayout>
  );
}
