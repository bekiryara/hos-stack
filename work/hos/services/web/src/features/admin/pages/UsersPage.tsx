import React, { useCallback, useEffect, useState } from 'react';
import { adminUpdateUserRole, adminUserLifecycle, adminUsers } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';
import { confirmRiskyAction, trAdminError } from '../utils/opsSafety';

type UserRole = 'member' | 'admin' | 'owner';
type UndoUserRole = { userId: string; role: UserRole };

export function UsersPage() {
  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [savingUserId, setSavingUserId] = useState<string | null>(null);
  const [nextRoleByUserId, setNextRoleByUserId] = useState<Record<string, UserRole>>({});
  const [message, setMessage] = useState<string | null>(null);
  const [undoRole, setUndoRole] = useState<UndoUserRole | null>(null);
  const [selectedUserIds, setSelectedUserIds] = useState<string[]>([]);
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
          next.map((u: any) => [u.id, (u.role || 'member') as UserRole])
        )
      );
      setSelectedUserIds((prev) => prev.filter((id) => next.some((u: any) => u.id === id)));
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Kullanicilar yuklenemedi'));
      setItems([]);
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

  const allSelected = items.length > 0 && selectedUserIds.length === items.length;
  const summary = React.useMemo(() => {
    const total = items.length;
    const owners = items.filter((x: any) => String(x.role || '') === 'owner').length;
    const admins = items.filter((x: any) => String(x.role || '') === 'admin').length;
    const googleLinked = items.filter((x: any) => Boolean(x.google_linked)).length;
    return { total, owners, admins, googleLinked, selected: selectedUserIds.length };
  }, [items, selectedUserIds.length]);

  async function handleSaveRole(userId: string) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    const role = nextRoleByUserId[userId] as UserRole | undefined;
    if (!role) return;
    const row = items.find((u: any) => u.id === userId);
    if (!row) return;
    const currentRole = (row.role || 'member') as UserRole;
    if (currentRole === role) return;

    const risk: 'low' | 'medium' | 'critical' =
      currentRole === 'owner' && role !== 'owner' ? 'critical' : role === 'owner' ? 'medium' : 'low';
    const ok = confirmRiskyAction({
      title: 'Kullanici rolu guncellenecek.',
      summary: `Kullanici: ${row.email || userId}\nFirma: ${row.tenant_slug || row.tenant_name || '-'}\nRol: ${currentRole} -> ${role}`,
      risk,
    });
    if (!ok) return;

    setSavingUserId(userId);
    setError(null);
    setActionError(null);
    setMessage(null);
    try {
      await adminUpdateUserRole(token, userId, role);
      setUndoRole({ userId, role: currentRole });
      setMessage('Rol guncellendi. Gerekirse geri alabilirsiniz.');
      await load();
    } catch (e: any) {
      setActionError(trAdminError(e?.body?.error || e?.message, 'Rol guncellenemedi'));
    } finally {
      setSavingUserId(null);
    }
  }

  async function handleUndoRole() {
    if (!undoRole) return;
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    setError(null);
    setMessage(null);
    try {
      await adminUpdateUserRole(token, undoRole.userId, undoRole.role);
      setUndoRole(null);
      setMessage('Son rol degisikligi geri alindi.');
      await load();
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Geri alma islemi basarisiz oldu'));
    }
  }

  async function handleDeactivateUser(row: any) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    const currentRole = (row.role || 'member') as UserRole;
    const risk: 'low' | 'medium' | 'critical' = currentRole === 'owner' ? 'critical' : 'medium';
    const ok = confirmRiskyAction({
      title: 'Kullanici pasife alinacak.',
      summary: `Kullanici: ${row.email || row.id}\nFirma: ${row.tenant_slug || row.tenant_name || '-'}\nBu islem aktif uyelikleri kapatir.`,
      risk,
    });
    if (!ok) return;

    const userId = String(row.id || '');
    if (!userId) return;
    setSavingUserId(userId);
    setError(null);
    setActionError(null);
    setMessage(null);
    setUndoRole(null);
    try {
      await adminUserLifecycle(token, userId, 'deactivate');
      setMessage('Kullanici pasife alindi.');
      await load();
    } catch (e: any) {
      setActionError(trAdminError(e?.body?.error || e?.message, 'Kullanici pasife alinamadi'));
    } finally {
      setSavingUserId(null);
    }
  }

  async function handleDeleteUser(row: any) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    const ok = confirmRiskyAction({
      title: 'Kullanici kalici olarak silinecek.',
      summary: `Kullanici: ${row.email || row.id}\nFirma: ${row.tenant_slug || row.tenant_name || '-'}\nBu islem geri alinamaz.`,
      risk: 'critical',
    });
    if (!ok) return;

    const userId = String(row.id || '');
    if (!userId) return;
    setSavingUserId(userId);
    setError(null);
    setActionError(null);
    setMessage(null);
    setUndoRole(null);
    try {
      await adminUserLifecycle(token, userId, 'delete');
      setMessage('Kullanici kalici olarak silindi.');
      await load();
    } catch (e: any) {
      setActionError(trAdminError(e?.body?.error || e?.message, 'Kullanici silinemedi'));
    } finally {
      setSavingUserId(null);
    }
  }

  async function handleBulkDeactivateUsers() {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    if (selectedUserIds.length === 0) return;

    const selectedRows = items.filter((x: any) => selectedUserIds.includes(String(x.id || '')));
    const ok = confirmRiskyAction({
      title: 'Secili kullanicilar pasife alinacak.',
      summary: `Secili kayit sayisi: ${selectedRows.length}\nBu islem secili kayitlarin aktif uyeliklerini kapatir.`,
      risk: 'medium',
    });
    if (!ok) return;

    setError(null);
    setActionError(null);
    setMessage(null);
    setUndoRole(null);
    let success = 0;
    const failed: string[] = [];
    for (const row of selectedRows) {
      const userId = String(row.id || '');
      if (!userId) continue;
      try {
        await adminUserLifecycle(token, userId, 'deactivate');
        success += 1;
      } catch {
        failed.push(row.email || userId);
      }
    }
    if (failed.length > 0) {
      setActionError(`Toplu pasife alma tamamlandi. Basarili: ${success}, Hatali: ${failed.length} (${failed.slice(0, 3).join(', ')})`);
    } else {
      setMessage(`Toplu pasife alma tamamlandi. Basarili: ${success}`);
    }
    await load();
    setSelectedUserIds([]);
  }

  async function handleBulkDeleteUsers() {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    if (selectedUserIds.length === 0) return;

    const selectedRows = items.filter((x: any) => selectedUserIds.includes(String(x.id || '')));
    const ok = confirmRiskyAction({
      title: 'Secili kullanicilar kalici olarak silinecek.',
      summary: `Secili kayit sayisi: ${selectedRows.length}\nBu islem geri alinamaz.`,
      risk: 'critical',
    });
    if (!ok) return;

    setError(null);
    setActionError(null);
    setMessage(null);
    setUndoRole(null);
    let success = 0;
    const failed: string[] = [];
    for (const row of selectedRows) {
      const userId = String(row.id || '');
      if (!userId) continue;
      try {
        await adminUserLifecycle(token, userId, 'delete');
        success += 1;
      } catch {
        failed.push(row.email || userId);
      }
    }
    if (failed.length > 0) {
      setActionError(`Toplu kalici silme tamamlandi. Basarili: ${success}, Hatali: ${failed.length} (${failed.slice(0, 3).join(', ')})`);
    } else {
      setMessage(`Toplu kalici silme tamamlandi. Basarili: ${success}`);
    }
    await load();
    setSelectedUserIds([]);
  }

  return (
    <AdminLayout title="Kullanicilar">
      <div className="card">
        <div className="title">Kullanicilar</div>
        <div className="card" style={{ marginBottom: '0.75rem', padding: '0.6rem 0.8rem' }}>
          <div style={{ display: 'flex', gap: '0.9rem', flexWrap: 'wrap', fontSize: '0.92rem' }}>
            <span>Toplam: <strong>{summary.total}</strong></span>
            <span>Secili: <strong>{summary.selected}</strong></span>
            <span>Owner: <strong>{summary.owners}</strong></span>
            <span>Admin: <strong>{summary.admins}</strong></span>
            <span>Google bagli: <strong>{summary.googleLinked}</strong></span>
          </div>
        </div>
        <div style={{ marginBottom: '0.75rem' }}>
          <button onClick={load} disabled={loading}>
            {loading ? 'Yenileniyor...' : 'Yenile'}
          </button>
          <button onClick={handleBulkDeactivateUsers} disabled={loading || selectedUserIds.length === 0} style={{ marginLeft: '0.5rem' }}>
            Secilileri Pasife Al ({selectedUserIds.length})
          </button>
          <button
            onClick={handleBulkDeleteUsers}
            disabled={loading || selectedUserIds.length === 0}
            style={{ marginLeft: '0.5rem', borderColor: 'rgba(248,113,113,.5)', color: '#fecaca' }}
          >
            Secilileri Kalici Sil ({selectedUserIds.length})
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
              {undoRole ? <button onClick={handleUndoRole}>Geri Al</button> : null}
            </div>
          </div>
        ) : null}
        {!error && items.length === 0 ? <p>Kullanici kaydi bulunamadi.</p> : null}
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
                        setSelectedUserIds(e.target.checked ? items.map((x: any) => String(x.id || '')) : [])
                      }
                    />
                  </th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Email</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Firma</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Rol</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Google</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Olusturulma</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Islemler</th>
                </tr>
              </thead>
              <tbody>
                {items.map((row: any) => (
                  <tr key={row.id}>
                    <td style={{ textAlign: 'center', padding: '0.6rem 0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <input
                        type="checkbox"
                        style={bulkCheckStyle}
                        checked={selectedUserIds.includes(String(row.id || ''))}
                        onChange={(e) =>
                          setSelectedUserIds((prev) =>
                            e.target.checked
                              ? Array.from(new Set([...prev, String(row.id || '')]))
                              : prev.filter((id) => id !== String(row.id || ''))
                          )
                        }
                      />
                    </td>
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
                            [row.id]: e.target.value as UserRole,
                          }))
                        }
                      >
                        <option value="member">member</option>
                        <option value="admin">admin</option>
                        <option value="owner">owner</option>
                      </select>
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.google_linked ? 'Evet' : 'Hayir'}</td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.created_at || '-'}</td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <div style={{ display: 'flex', gap: '0.45rem', flexWrap: 'wrap' }}>
                        <button onClick={() => handleSaveRole(row.id)} disabled={savingUserId === row.id}>
                          {savingUserId === row.id ? 'Kaydediliyor...' : 'Kaydet'}
                        </button>
                        <button onClick={() => handleDeactivateUser(row)} disabled={savingUserId === row.id}>
                          Pasife Al
                        </button>
                        <button onClick={() => handleDeleteUser(row)} disabled={savingUserId === row.id}>
                          Sil
                        </button>
                      </div>
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
