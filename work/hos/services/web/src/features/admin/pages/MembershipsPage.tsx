import React, { useCallback, useEffect, useState } from 'react';
import { adminMemberships, adminUpdateMembership } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';

export function MembershipsPage() {
  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [savingUserId, setSavingUserId] = useState<string | null>(null);
  const [draftByUserId, setDraftByUserId] = useState<
    Record<string, { role: 'member' | 'admin' | 'owner'; status: 'active' | 'inactive' | 'suspended' }>
  >({});

  const load = useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Token bulunamadi. Once giris yapin.');
      setItems([]);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const out = await adminMemberships(token);
      const next = Array.isArray(out?.items) ? out.items : Array.isArray(out) ? out : [];
      setItems(next);
      setDraftByUserId(
        Object.fromEntries(
          next.map((m: any) => [
            m.user_id,
            {
              role: (m.role || 'member') as 'member' | 'admin' | 'owner',
              status: (m.status || 'active') as 'active' | 'inactive' | 'suspended',
            },
          ])
        )
      );
    } catch (e: any) {
      setError(e?.body?.error || e?.message || 'Uyelikler alinamadi');
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function handleSave(userId: string) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Token bulunamadi. Once giris yapin.');
      return;
    }
    const draft = draftByUserId[userId];
    if (!draft) return;

    setSavingUserId(userId);
    setError(null);
    try {
      await adminUpdateMembership(token, userId, {
        role: draft.role,
        status: draft.status,
      });
      await load();
    } catch (e: any) {
      setError(e?.body?.error || e?.message || 'Uyelik guncellenemedi');
    } finally {
      setSavingUserId(null);
    }
  }

  return (
    <AdminLayout title="Uyelikler">
      <div className="card">
        <div className="title">Tenant Uyelik Yonetimi</div>
        <div style={{ marginBottom: '0.75rem' }}>
          <button onClick={load} disabled={loading}>
            {loading ? 'Yukleniyor...' : 'Yenile'}
          </button>
        </div>
        {error ? (
          <div className="card error">
            <div className="title">Hata</div>
            <pre>{String(error)}</pre>
          </div>
        ) : null}
        {!error && items.length === 0 ? <p>Aktif uyelik kaydi bulunamadi.</p> : null}
        {items.length > 0 ? (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Kullanici</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Tenant</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Rol</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Durum</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Olusturulma</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Aksiyon</th>
                </tr>
              </thead>
              <tbody>
                {items.map((row: any) => (
                  <tr key={`${row.tenant_id}-${row.user_id}`}>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      {row.user_email || row.user_display_name || row.user_id || '-'}
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      {row.tenant_name || row.tenant_slug || row.tenant_id || '-'}
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <select
                        value={draftByUserId[row.user_id]?.role || (row.role || 'member')}
                        onChange={(e) =>
                          setDraftByUserId((prev) => ({
                            ...prev,
                            [row.user_id]: {
                              role: e.target.value as 'member' | 'admin' | 'owner',
                              status: prev[row.user_id]?.status || (row.status || 'active'),
                            },
                          }))
                        }
                      >
                        <option value="member">member</option>
                        <option value="admin">admin</option>
                        <option value="owner">owner</option>
                      </select>
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <select
                        value={draftByUserId[row.user_id]?.status || (row.status || 'active')}
                        onChange={(e) =>
                          setDraftByUserId((prev) => ({
                            ...prev,
                            [row.user_id]: {
                              role: prev[row.user_id]?.role || (row.role || 'member'),
                              status: e.target.value as 'active' | 'inactive' | 'suspended',
                            },
                          }))
                        }
                      >
                        <option value="active">active</option>
                        <option value="inactive">inactive</option>
                        <option value="suspended">suspended</option>
                      </select>
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.created_at || '-'}</td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <button onClick={() => handleSave(row.user_id)} disabled={savingUserId === row.user_id}>
                        {savingUserId === row.user_id ? 'Kaydediliyor...' : 'Kaydet'}
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
