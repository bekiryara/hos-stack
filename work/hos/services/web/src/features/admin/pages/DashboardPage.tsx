import React from 'react';
import { AdminLayout } from '../layout/AdminLayout';
import { getHealth, getWorlds } from '../../../lib/api';

export function DashboardPage() {
  const [loading, setLoading] = React.useState(false);
  const [health, setHealth] = React.useState<any>(null);
  const [worlds, setWorlds] = React.useState<any[]>([]);
  const [error, setError] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [h, w] = await Promise.all([getHealth(), getWorlds()]);
      setHealth(h);
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
        <pre style={{ marginTop: 0 }}>{JSON.stringify(health, null, 2)}</pre>
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
