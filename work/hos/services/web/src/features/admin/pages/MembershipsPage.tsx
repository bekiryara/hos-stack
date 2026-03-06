import React, { useCallback, useEffect, useState } from 'react';
import { adminMemberships } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';

export function MembershipsPage() {
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
      const out = await adminMemberships(token);
      const next = Array.isArray(out?.items) ? out.items : Array.isArray(out) ? out : [];
      setItems(next);
    } catch (e: any) {
      setError(e?.body?.error || e?.message || 'Failed to load memberships');
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <AdminLayout title="Memberships">
      <div className="card">
        <div className="title">Memberships</div>
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
        {!error && items.length === 0 ? <p>Membership kaydi bulunamadi.</p> : null}
        {items.length > 0 ? (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>User</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Tenant</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Role</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Status</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Created</th>
                </tr>
              </thead>
              <tbody>
                {items.map((row: any) => (
                  <tr key={`${row.tenant_id}:${row.user_id}`}>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      {row.user_email || row.user_display_name || row.user_id || '-'}
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      {row.tenant_slug || row.tenant_name || row.tenant_id || '-'}
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.role || '-'}</td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.status || '-'}</td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.created_at || '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </div>
    </AdminLayout>
  );
}

