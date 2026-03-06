import React, { useCallback, useEffect, useState } from 'react';
import { adminUpdateUserRole, adminUsers } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';

export function UsersPage() {
  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [savingUserId, setSavingUserId] = useState<string | null>(null);
  const [nextRoleByUserId, setNextRoleByUserId] = useState<Record<string, 'member' | 'admin' | 'owner'>>({});

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
      const out = await adminUsers(token);
      const next = Array.isArray(out?.items) ? out.items : Array.isArray(out) ? out : [];
      setItems(next);
      setNextRoleByUserId(
        Object.fromEntries(
          next.map((u: any) => [u.id, (u.role || 'member') as 'member' | 'admin' | 'owner'])
        )
      );
    } catch (e: any) {
      setError(e?.body?.error || e?.message || 'Failed to load users');
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function handleSaveRole(userId: string) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Missing token. Please login from Control Center first.');
      return;
    }
    const role = nextRoleByUserId[userId];
    if (!role) return;

    setSavingUserId(userId);
    setError(null);
    try {
      await adminUpdateUserRole(token, userId, role);
      await load();
    } catch (e: any) {
      setError(e?.body?.error || e?.message || 'Failed to update role');
    } finally {
      setSavingUserId(null);
    }
  }

  return (
    <AdminLayout title="Users">
      <div className="card">
        <div className="title">Users</div>
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
        {!error && items.length === 0 ? <p>Kullanici kaydi bulunamadi.</p> : null}
        {items.length > 0 ? (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Email</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Tenant</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Role</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Google</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Created</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map((row: any) => (
                  <tr key={row.id}>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.email || '-'}</td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      {row.tenant_slug || row.tenant_name || '-'}
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <select
                        value={nextRoleByUserId[row.id] || (row.role || 'member')}
                        style={{ background: '#111b2e', color: '#e5e7eb', border: '1px solid rgba(255,255,255,.2)', borderRadius: '6px' }}
                        onChange={(e) =>
                          setNextRoleByUserId((prev) => ({
                            ...prev,
                            [row.id]: e.target.value as 'member' | 'admin' | 'owner',
                          }))
                        }
                      >
                        <option value="member">member</option>
                        <option value="admin">admin</option>
                        <option value="owner">owner</option>
                      </select>
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.google_linked ? 'Yes' : 'No'}</td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.created_at || '-'}</td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <button onClick={() => handleSaveRole(row.id)} disabled={savingUserId === row.id}>
                        {savingUserId === row.id ? 'Saving...' : 'Save'}
                      </button>
                    </td>
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
