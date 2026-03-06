import React, { useCallback, useEffect, useState } from 'react';
import { adminAudit } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';

export function AuditPage() {
  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Missing token. Please login from Control Center first.');
      setItems([]);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const out = await adminAudit(token, 50);
      const next = Array.isArray(out?.items) ? out.items : Array.isArray(out) ? out : [];
      setItems(next);
    } catch (e: any) {
      setError(e?.body?.error || e?.message || 'Failed to load audit');
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <AdminLayout title="Audit">
      <div className="card">
        <div className="title">Audit Stream</div>
        <div style={{ marginBottom: '0.75rem' }}>
          <button onClick={load} disabled={loading}>
            {loading ? 'Refreshing...' : 'Refresh'}
          </button>
        </div>
        {error ? (
          <div className="card error">
            <div className="title">Error</div>
            <pre>{String(error)}</pre>
          </div>
        ) : null}
        {!error && items.length === 0 ? <p>No audit events found.</p> : null}
        {items.length > 0 ? (
          <div style={{ display: 'grid', gap: '0.6rem' }}>
            {items.map((row: any) => (
              <div key={row.id} className="card" style={{ padding: '0.6rem 0.8rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.75rem', flexWrap: 'wrap' }}>
                  <strong>{row.action || '-'}</strong>
                  <span style={{ color: '#9ca3af' }}>{row.created_at || '-'}</span>
                </div>
                <div style={{ fontSize: '0.9rem', marginTop: '0.35rem' }}>
                  actor: <code>{row.actor_user_id || '-'}</code>
                </div>
                {row.metadata ? <pre style={{ marginTop: '0.4rem' }}>{JSON.stringify(row.metadata, null, 2)}</pre> : null}
              </div>
            ))}
          </div>
        ) : null}
      </div>
    </AdminLayout>
  );
}
