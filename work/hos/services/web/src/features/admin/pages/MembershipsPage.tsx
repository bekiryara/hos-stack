import React, { useCallback, useEffect, useState } from 'react';
import { adminMembershipLifecycle, adminMemberships, adminUpdateMembership } from '../api/adminClient';
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
  const [actionError, setActionError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [savingKey, setSavingKey] = useState<string | null>(null);
  const [nextByKey, setNextByKey] = useState<Record<string, { role: MembershipRole; status: MembershipStatus }>>({});
  const [undoMembership, setUndoMembership] = useState<UndoMembership | null>(null);
  const [selectedKeys, setSelectedKeys] = useState<string[]>([]);
  const bulkCheckStyle: React.CSSProperties = {
    width: '1.15rem',
    height: '1.15rem',
    accentColor: '#60a5fa',
    cursor: 'pointer',
  };

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
      setSelectedKeys((prev) => prev.filter((k) => next.some((m: any) => `${m.tenant_id}:${m.user_id}` === k)));
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

  useEffect(() => {
    if (!actionError) return;
    const t = window.setTimeout(() => setActionError(null), 7000);
    return () => window.clearTimeout(t);
  }, [actionError]);

  const allSelected = items.length > 0 && selectedKeys.length === items.length;

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
    setActionError(null);
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
      setActionError(trAdminError(e?.body?.error || e?.message, 'Uyelik guncellenemedi'));
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
    setActionError(null);
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
      setActionError(trAdminError(e?.body?.error || e?.message, 'Geri alma islemi basarisiz oldu'));
    }
  }

  async function handleDeactivateMembership(row: any) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    const currentRole = (row.role || 'member') as MembershipRole;
    const risk: 'low' | 'medium' | 'critical' = currentRole === 'owner' ? 'critical' : 'medium';
    const ok = confirmRiskyAction({
      title: 'Uyelik pasife alinacak.',
      summary: `Kullanici: ${row.user_email || row.user_id}\nFirma: ${row.tenant_slug || row.tenant_id}\nBu islem uyeligi kapatir.`,
      risk,
    });
    if (!ok) return;

    const key = `${row.tenant_id}:${row.user_id}`;
    setSavingKey(key);
    setError(null);
    setActionError(null);
    setMessage(null);
    try {
      await adminMembershipLifecycle(token, String(row.tenant_id), String(row.user_id), 'deactivate');
      setMessage('Uyelik pasife alindi.');
      await load();
    } catch (e: any) {
      setActionError(trAdminError(e?.body?.error || e?.message, 'Uyelik pasife alinamadi'));
    } finally {
      setSavingKey(null);
    }
  }

  async function handleDeleteMembership(row: any) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    const ok = confirmRiskyAction({
      title: 'Uyelik kalici olarak silinecek.',
      summary: `Kullanici: ${row.user_email || row.user_id}\nFirma: ${row.tenant_slug || row.tenant_id}\nBu islem geri alinamaz.`,
      risk: 'critical',
    });
    if (!ok) return;

    const key = `${row.tenant_id}:${row.user_id}`;
    setSavingKey(key);
    setError(null);
    setActionError(null);
    setMessage(null);
    try {
      await adminMembershipLifecycle(token, String(row.tenant_id), String(row.user_id), 'delete');
      setMessage('Uyelik kalici olarak silindi.');
      await load();
    } catch (e: any) {
      setActionError(trAdminError(e?.body?.error || e?.message, 'Uyelik silinemedi'));
    } finally {
      setSavingKey(null);
    }
  }

  async function handleBulkDeactivateMemberships() {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    if (selectedKeys.length === 0) return;

    const selectedRows = items.filter((m: any) => selectedKeys.includes(`${m.tenant_id}:${m.user_id}`));
    const ok = confirmRiskyAction({
      title: 'Secili uyelikler pasife alinacak.',
      summary: `Secili kayit sayisi: ${selectedRows.length}\nBu islem secili uyelikleri inactive yapar.`,
      risk: 'medium',
    });
    if (!ok) return;

    setError(null);
    setActionError(null);
    setMessage(null);
    let success = 0;
    const failed: string[] = [];
    for (const row of selectedRows) {
      try {
        await adminMembershipLifecycle(token, String(row.tenant_id), String(row.user_id), 'deactivate');
        success += 1;
      } catch {
        failed.push(row.user_email || row.user_id);
      }
    }
    if (failed.length > 0) {
      setActionError(`Toplu pasife alma tamamlandi. Basarili: ${success}, Hatali: ${failed.length} (${failed.slice(0, 3).join(', ')})`);
    } else {
      setMessage(`Toplu pasife alma tamamlandi. Basarili: ${success}`);
    }
    await load();
    setSelectedKeys([]);
  }

  async function handleBulkDeleteMemberships() {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    if (selectedKeys.length === 0) return;

    const selectedRows = items.filter((m: any) => selectedKeys.includes(`${m.tenant_id}:${m.user_id}`));
    const ok = confirmRiskyAction({
      title: 'Secili uyelikler kalici olarak silinecek.',
      summary: `Secili kayit sayisi: ${selectedRows.length}\nBu islem geri alinamaz.`,
      risk: 'critical',
    });
    if (!ok) return;

    setError(null);
    setActionError(null);
    setMessage(null);
    let success = 0;
    const failed: string[] = [];
    for (const row of selectedRows) {
      try {
        await adminMembershipLifecycle(token, String(row.tenant_id), String(row.user_id), 'delete');
        success += 1;
      } catch {
        failed.push(row.user_email || row.user_id);
      }
    }
    if (failed.length > 0) {
      setActionError(`Toplu kalici silme tamamlandi. Basarili: ${success}, Hatali: ${failed.length} (${failed.slice(0, 3).join(', ')})`);
    } else {
      setMessage(`Toplu kalici silme tamamlandi. Basarili: ${success}`);
    }
    await load();
    setSelectedKeys([]);
  }

  return (
    <AdminLayout title="Uyelikler">
      <div className="card">
        <div className="title">Uyelikler</div>
        <div style={{ marginBottom: '0.75rem' }}>
          <button onClick={load} disabled={loading}>
            {loading ? 'Yenileniyor...' : 'Yenile'}
          </button>
          <button onClick={handleBulkDeactivateMemberships} disabled={loading || selectedKeys.length === 0} style={{ marginLeft: '0.5rem' }}>
            Secilileri Pasife Al ({selectedKeys.length})
          </button>
          <button
            onClick={handleBulkDeleteMemberships}
            disabled={loading || selectedKeys.length === 0}
            style={{ marginLeft: '0.5rem', borderColor: 'rgba(248,113,113,.5)', color: '#fecaca' }}
          >
            Secilileri Kalici Sil ({selectedKeys.length})
          </button>
        </div>
        {error ? (
          <div className="card error">
            <div className="title">Hata</div>
            <pre>{String(error)}</pre>
          </div>
        ) : null}
        {actionError ? (
          <div className="card" style={{ marginBottom: '0.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '0.75rem' }}>
              <pre style={{ margin: 0 }}>{actionError}</pre>
              <button onClick={() => setActionError(null)}>Kapat</button>
            </div>
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
                  <th style={{ textAlign: 'center', width: '2.5rem', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.6rem 0.45rem' }}>
                    <input
                      type="checkbox"
                      style={bulkCheckStyle}
                      checked={allSelected}
                      onChange={(e) =>
                        setSelectedKeys(
                          e.target.checked ? items.map((m: any) => `${m.tenant_id}:${m.user_id}`) : []
                        )
                      }
                    />
                  </th>
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
                    <td style={{ textAlign: 'center', padding: '0.6rem 0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <input
                        type="checkbox"
                        style={bulkCheckStyle}
                        checked={selectedKeys.includes(key)}
                        onChange={(e) =>
                          setSelectedKeys((prev) =>
                            e.target.checked ? Array.from(new Set([...prev, key])) : prev.filter((k) => k !== key)
                          )
                        }
                      />
                    </td>
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
                      <div style={{ display: 'flex', gap: '0.45rem', flexWrap: 'wrap' }}>
                        <button onClick={() => handleSave(row)} disabled={!changed || savingKey === key}>
                          {savingKey === key ? 'Kaydediliyor...' : 'Kaydet'}
                        </button>
                        <button onClick={() => handleDeactivateMembership(row)} disabled={savingKey === key}>
                          Pasife Al
                        </button>
                        <button onClick={() => handleDeleteMembership(row)} disabled={savingKey === key}>
                          Sil
                        </button>
                      </div>
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
