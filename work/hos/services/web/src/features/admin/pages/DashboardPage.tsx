import React from 'react';
import { AdminLayout } from '../layout/AdminLayout';
import { getWorlds } from '../../../lib/api';
import { adminOverview } from '../api/adminClient';

export function DashboardPage() {
  const [loading, setLoading] = React.useState(false);
  const [overview, setOverview] = React.useState<any>(null);
  const [worlds, setWorlds] = React.useState<any[]>([]);
  const [error, setError] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Missing token. Please login from Control Center first.');
      setOverview(null);
      setWorlds([]);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const [o, w] = await Promise.all([adminOverview(token), getWorlds()]);
      setOverview(o);
      setWorlds(Array.isArray(w) ? w : []);
    } catch (e: any) {
      setError(e?.message || 'Sistem durumu alinamadi');
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
        <div className="title">Dunya Durumu</div>
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
        <pre style={{ marginTop: 0 }}>{JSON.stringify(overview, null, 2)}</pre>
        <div style={{ display: 'grid', gap: '0.45rem', marginTop: '0.75rem' }}>
          {worlds.map((world: any) => (
            <div key={world.world_key} style={{ border: '1px solid rgba(255,255,255,.15)', borderRadius: 8, padding: '0.5rem 0.65rem' }}>
              <strong>{world.world_key}</strong> - {world.availability || '-'} - {world.phase || '-'} v{world.version || '-'}
            </div>
          ))}
        </div>
      </div>
    </AdminLayout>
  );
}
