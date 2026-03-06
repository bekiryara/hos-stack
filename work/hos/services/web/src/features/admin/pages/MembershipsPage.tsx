import React, { useCallback, useEffect, useState } from 'react';
import { adminMemberships, adminUpdateMembership } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';
import { confirmRiskyAction, trAdminError } from '../utils/opsSafety';

type MembershipRole = 'member' | 'admin' | 'owner';
type MembershipStatus = 'active' | 'inactive' | 'suspended';
type UndoMembership = {
  tenantId: string;
  userId: string;
  role: MembershipRole;
  status: MembershipStatus;
};

export function MembershipsPage() {
  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [savingKey, setSavingKey] = useState<string | null>(null);
  const [nextByKey, setNextByKey] = useState<Record<string, { role: MembershipRole; status: MembershipStatus }>>({});
  const [undoMembership, setUndoMembership] = useState<UndoMembership | null>(null);

  const load = useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      setItems([]);
      setNextByKey({});
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const out = await adminMemberships(token);
      const next = Array.isArray(out?.items) ? out.items : Array.isArray(out) ? out : [];
      setItems(next);
      setNextByKey(
        Object.fromEntries(
          next.map((m: any) => [
            `${m.tenant_id}:${m.user_id}`,
            {
              role: (m.role || 'member') as MembershipRole,
              status: (m.status || 'active') as MembershipStatus,
            },
          ])
        )
      );
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Uyelikler yuklenemedi'));
      setItems([]);
      setNextByKey({});
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function handleSave(row: any) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }

    const key = `${row.tenant_id}:${row.user_id}`;
    const patch = nextByKey[key];
    if (!patch) return;

    const currentRole = (row.role || 'member') as MembershipRole;
    const currentStatus = (row.status || 'active') as MembershipStatus;
    if (patch.role === currentRole && patch.status === currentStatus) return;

    const risk: 'low' | 'medium' | 'critical' =
      currentRole === 'owner' && patch.role !== 'owner'
        ? 'critical'
        : patch.status !== 'active'
          ? 'medium'
          : 'low';
    const ok = confirmRiskyAction({
      title: 'Bu uyelik guncellenecek.',
      summary: `Kullanici: ${row.user_email || row.user_id}\nFirma: ${row.tenant_slug || row.tenant_id}\nRol: ${currentRole} -> ${patch.role}\nDurum: ${currentStatus} -> ${patch.status}`,
      risk,
    });
    if (!ok) return;

    setSavingKey(key);
    setError(null);
    setMessage(null);
    try {
      await adminUpdateMembership(token, String(row.tenant_id), String(row.user_id), patch);
      setUndoMembership({
        tenantId: String(row.tenant_id),
        userId: String(row.user_id),
        role: currentRole,
        status: currentStatus,
      });
      setMessage('Uyelik guncellendi. Gerekirse geri alabilirsiniz.');
      await load();
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Uyelik guncellenemedi'));
    } finally {
      setSavingKey(null);
    }
  }

  async function handleUndoMembership() {
    if (!undoMembership) return;
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    setError(null);
    setMessage(null);
    try {
      await adminUpdateMembership(token, undoMembership.tenantId, undoMembership.userId, {
        role: undoMembership.role,
        status: undoMembership.status,
      });
      setUndoMembership(null);
      setMessage('Son degisiklik geri alindi.');
      await load();
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Geri alma islemi basarisiz oldu'));
    }
  }

  return (
    <AdminLayout title="Uyelikler">
      <div className="card">
        <div className="title">Uyelikler</div>
        <div style={{ marginBottom: '0.75rem' }}>
          <button onClick={load} disabled={loading}>
            {loading ? 'Yenileniyor...' : 'Yenile'}
          </button>
        </div>
        {error ? (
          <div className="card error">
            <div className="title">Hata</div>
            <pre>{String(error)}</pre>
          </div>
        ) : null}
        {message ? (
          <div className="card" style={{ marginBottom: '0.75rem' }}>
            <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', flexWrap: 'wrap' }}>
              <pre style={{ margin: 0 }}>{message}</pre>
              {undoMembership ? (
                <button onClick={handleUndoMembership}>
                  Geri Al
                </button>
              ) : null}
            </div>
          </div>
        ) : null}
        {!error && items.length === 0 ? <p>Membership kaydi bulunamadi.</p> : null}
        {items.length > 0 ? (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Kullanici</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Firma</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Rol</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Durum</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Olusturulma</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Islemler</th>
                </tr>
              </thead>
              <tbody>
                {items.map((row: any) => {
                  const key = `${row.tenant_id}:${row.user_id}`;
                  const currentRole = (row.role || 'member') as MembershipRole;
                  const currentStatus = (row.status || 'active') as MembershipStatus;
                  const next = nextByKey[key] || { role: currentRole, status: currentStatus };
                  const changed = next.role !== currentRole || next.status !== currentStatus;
                  return (
                  <tr key={key}>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      {row.user_email || row.user_display_name || row.user_id || '-'}
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      {row.tenant_slug || row.tenant_name || row.tenant_id || '-'}
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <select
                        value={next.role}
                        style={{ background: '#111b2e', color: '#e5e7eb', border: '1px solid rgba(255,255,255,.2)', borderRadius: '6px' }}
                        onChange={(e) =>
                          setNextByKey((prev) => ({
                            ...prev,
                            [key]: { ...next, role: e.target.value as MembershipRole },
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
                        value={next.status}
                        style={{ background: '#111b2e', color: '#e5e7eb', border: '1px solid rgba(255,255,255,.2)', borderRadius: '6px' }}
                        onChange={(e) =>
                          setNextByKey((prev) => ({
                            ...prev,
                            [key]: { ...next, status: e.target.value as MembershipStatus },
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
                      <button onClick={() => handleSave(row)} disabled={!changed || savingKey === key}>
                        {savingKey === key ? 'Kaydediliyor...' : 'Kaydet'}
                      </button>
                    </td>
                  </tr>
                )})}
              </tbody>
            </table>
          </div>
        ) : null}
      </div>
    </AdminLayout>
  );
}
