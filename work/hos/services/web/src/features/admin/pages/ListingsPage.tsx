import React from 'react';
import { adminListingLifecycle, adminListings } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';
import { confirmRiskyAction, trAdminError } from '../utils/opsSafety';

type ListingStatus = 'all' | 'draft' | 'published' | 'paused' | 'archived';
type ListingAction = 'publish' | 'pause' | 'archive' | 'delete';
type UndoAction = 'publish' | 'pause';
type BulkRowResult = { id: string; title: string; ok: boolean; message: string };
type UndoEntry = { id: string; title: string; action: UndoAction };

const STATUS_TR: Record<string, string> = {
  draft: 'Taslak',
  published: 'Yayinda',
  paused: 'Durduruldu',
  archived: 'Arsiv',
};

function fmtDate(v: any): string {
  const s = String(v || '').trim();
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('tr-TR');
  } catch {
    return s;
  }
}

function fmtPrice(amount: any, currency: any): string {
  if (amount === null || amount === undefined || amount === '') return '-';
  const n = Number(amount);
  if (!Number.isFinite(n)) return '-';
  const cur = String(currency || 'TRY').toUpperCase();
  try {
    return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: cur, maximumFractionDigits: 0 }).format(n);
  } catch {
    return `${n} ${cur}`;
  }
}

export function ListingsPage() {
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [actionError, setActionError] = React.useState<string | null>(null);
  const [message, setMessage] = React.useState<string | null>(null);
  const [savingId, setSavingId] = React.useState<string | null>(null);
  const [items, setItems] = React.useState<any[]>([]);
  const [total, setTotal] = React.useState(0);
  const [status, setStatus] = React.useState<ListingStatus>('all');
  const [tenantId, setTenantId] = React.useState('');
  const [q, setQ] = React.useState('');
  const [selectedIds, setSelectedIds] = React.useState<string[]>([]);
  const [bulkResults, setBulkResults] = React.useState<BulkRowResult[] | null>(null);
  const [undoEntries, setUndoEntries] = React.useState<UndoEntry[] | null>(null);
  const [undoUntilTs, setUndoUntilTs] = React.useState<number>(0);
  const [nowTs, setNowTs] = React.useState<number>(() => Date.now());

  const bulkCheckStyle: React.CSSProperties = {
    width: '1.15rem',
    height: '1.15rem',
    accentColor: '#60a5fa',
    cursor: 'pointer',
  };

  const load = React.useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      setItems([]);
      setTotal(0);
      return;
    }

    setLoading(true);
    setError(null);
    setActionError(null);
    try {
      const out = await adminListings(token, {
        status,
        tenant_id: tenantId || undefined,
        q: q || undefined,
        page: 1,
        per_page: 100,
      });
      const next = Array.isArray(out?.items) ? out.items : [];
      setItems(next);
      setTotal(Number(out?.total || next.length));
      setSelectedIds((prev) => prev.filter((id) => next.some((x: any) => String(x?.id || '') === id)));
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Ilanlar yuklenemedi'));
      setItems([]);
      setTotal(0);
      setSelectedIds([]);
    } finally {
      setLoading(false);
    }
  }, [q, status, tenantId]);

  React.useEffect(() => {
    void load();
  }, [load]);

  const summary = React.useMemo(() => {
    const draft = items.filter((x: any) => String(x?.status || '') === 'draft').length;
    const published = items.filter((x: any) => String(x?.status || '') === 'published').length;
    const paused = items.filter((x: any) => String(x?.status || '') === 'paused').length;
    const archived = items.filter((x: any) => String(x?.status || '') === 'archived').length;
    return { total, draft, published, paused, archived, selected: selectedIds.length };
  }, [items, total, selectedIds.length]);

  const allSelected = items.length > 0 && selectedIds.length === items.length;
  const undoRemainingSec = Math.max(0, Math.floor((undoUntilTs - nowTs) / 1000));
  const undoActive = Boolean(undoEntries && undoEntries.length > 0 && undoRemainingSec > 0);

  React.useEffect(() => {
    if (!undoActive) return;
    const t = window.setInterval(() => setNowTs(Date.now()), 1000);
    return () => window.clearInterval(t);
  }, [undoActive]);

  function actionRisk(action: ListingAction): 'low' | 'medium' | 'critical' {
    if (action === 'archive' || action === 'delete') return 'critical';
    if (action === 'pause') return 'medium';
    return 'low';
  }

  function actionLabel(action: ListingAction): string {
    if (action === 'publish') return 'Yayina Al';
    if (action === 'pause') return 'Durdur';
    if (action === 'archive') return 'Arsivle';
    return 'Kalici Sil';
  }

  function reverseFor(action: ListingAction): UndoAction | null {
    if (action === 'publish') return 'pause';
    if (action === 'pause') return 'publish';
    return null;
  }

  function startUndoWindow(entries: UndoEntry[]) {
    if (!entries.length) return;
    setUndoEntries(entries);
    setUndoUntilTs(Date.now() + 2 * 60 * 1000);
    setNowTs(Date.now());
  }

  async function runListingAction(row: any, action: ListingAction) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }

    const id = String(row?.id || '');
    if (!id) return;
    const statusNow = String(row?.status || '');
    const ok = confirmRiskyAction({
      title: `Ilan ${actionLabel(action)} islemi uygulanacak.`,
      summary: `Ilan: ${row?.title || id}\nIlan ID: ${id}\nDurum: ${STATUS_TR[statusNow] || statusNow}${action === 'delete' ? '\nBu islem geri alinamaz.' : ''}`,
      risk: actionRisk(action),
    });
    if (!ok) return;

    setSavingId(id);
    setActionError(null);
    setMessage(null);
    setBulkResults(null);
    try {
      await adminListingLifecycle(token, id, action);
      setMessage(`Ilan islemi basarili: ${actionLabel(action)}`);
      const reverse = reverseFor(action);
      if (reverse) {
        startUndoWindow([{ id, title: String(row?.title || id), action: reverse }]);
      } else {
        setUndoEntries(null);
        setUndoUntilTs(0);
      }
      await load();
    } catch (e: any) {
      setActionError(trAdminError(e?.body?.error || e?.message, 'Ilan islemi tamamlanamadi'));
    } finally {
      setSavingId(null);
    }
  }

  async function runBulkAction(action: ListingAction) {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    if (selectedIds.length === 0) return;

    const selected = items.filter((x: any) => selectedIds.includes(String(x?.id || '')));
    const ok = confirmRiskyAction({
      title: `Secili ilanlara ${actionLabel(action)} islemi uygulanacak.`,
      summary: `Secili kayit sayisi: ${selected.length}${action === 'delete' ? '\nBu islem geri alinamaz.' : ''}`,
      risk: actionRisk(action),
    });
    if (!ok) return;

    setActionError(null);
    setMessage(null);
    setBulkResults(null);
    const results: BulkRowResult[] = [];
    const undo: UndoEntry[] = [];
    const reverse = reverseFor(action);
    for (const row of selected) {
      const id = String(row?.id || '');
      if (!id) continue;
      try {
        await adminListingLifecycle(token, id, action);
        results.push({ id, title: String(row?.title || id), ok: true, message: 'Basarili' });
        if (reverse) undo.push({ id, title: String(row?.title || id), action: reverse });
      } catch (e: any) {
        results.push({
          id,
          title: String(row?.title || id),
          ok: false,
          message: trAdminError(e?.body?.error || e?.message, 'Islem hatasi'),
        });
      }
    }
    const success = results.filter((r) => r.ok).length;
    const failed = results.length - success;
    setBulkResults(results);
    if (failed > 0) {
      setActionError(`Toplu islem tamamlandi. Basarili: ${success}, Hatali: ${failed}`);
    } else {
      setMessage(`Toplu islem tamamlandi. Basarili: ${success}`);
    }
    if (undo.length > 0) startUndoWindow(undo);
    else {
      setUndoEntries(null);
      setUndoUntilTs(0);
    }
    await load();
    setSelectedIds([]);
  }

  async function runUndo() {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    if (!undoActive || !undoEntries) return;
    setActionError(null);
    setMessage(null);
    const results: BulkRowResult[] = [];
    for (const entry of undoEntries) {
      try {
        await adminListingLifecycle(token, entry.id, entry.action);
        results.push({ id: entry.id, title: entry.title, ok: true, message: 'Geri alma basarili' });
      } catch (e: any) {
        results.push({
          id: entry.id,
          title: entry.title,
          ok: false,
          message: trAdminError(e?.body?.error || e?.message, 'Geri alma hatasi'),
        });
      }
    }
    const success = results.filter((r) => r.ok).length;
    const failed = results.length - success;
    setBulkResults(results);
    if (failed > 0) setActionError(`Geri alma tamamlandi. Basarili: ${success}, Hatali: ${failed}`);
    else setMessage(`Geri alma tamamlandi. Basarili: ${success}`);
    setUndoEntries(null);
    setUndoUntilTs(0);
    await load();
  }

  return (
    <AdminLayout title="Ilanlar">
      <div className="card">
        <div className="title">Ilan Yonetimi</div>
        <div className="card" style={{ marginBottom: '0.75rem', padding: '0.6rem 0.8rem' }}>
          <div style={{ display: 'flex', gap: '0.9rem', flexWrap: 'wrap', fontSize: '0.92rem' }}>
            <span>Toplam: <strong>{summary.total}</strong></span>
            <span>Secili: <strong>{summary.selected}</strong></span>
            <span>Taslak: <strong>{summary.draft}</strong></span>
            <span>Yayinda: <strong>{summary.published}</strong></span>
            <span>Durduruldu: <strong>{summary.paused}</strong></span>
            <span>Arsiv: <strong>{summary.archived}</strong></span>
          </div>
        </div>

        <div className="card" style={{ marginBottom: '0.75rem', padding: '0.6rem 0.8rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '0.6rem' }}>
            <label style={{ display: 'grid', gap: '0.35rem' }}>
              <span>Durum</span>
              <select value={status} onChange={(e) => setStatus(e.target.value as ListingStatus)}>
                <option value="all">Hepsi</option>
                <option value="draft">Taslak</option>
                <option value="published">Yayinda</option>
                <option value="paused">Durduruldu</option>
                <option value="archived">Arsiv</option>
              </select>
            </label>
            <label style={{ display: 'grid', gap: '0.35rem' }}>
              <span>Firma ID</span>
              <input value={tenantId} onChange={(e) => setTenantId(e.target.value)} placeholder="or: 59704a80-..." />
            </label>
            <label style={{ display: 'grid', gap: '0.35rem' }}>
              <span>Arama</span>
              <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Baslik / Ilan ID / Firma ID" />
            </label>
          </div>
          <div style={{ marginTop: '0.7rem' }}>
            <button onClick={load} disabled={loading}>{loading ? 'Yukleniyor...' : 'Filtreyi Uygula'}</button>
            <button onClick={() => runBulkAction('publish')} disabled={loading || selectedIds.length === 0} style={{ marginLeft: '0.5rem' }}>
              Secilileri Yayina Al ({selectedIds.length})
            </button>
            <button onClick={() => runBulkAction('pause')} disabled={loading || selectedIds.length === 0} style={{ marginLeft: '0.5rem' }}>
              Secilileri Durdur ({selectedIds.length})
            </button>
            <button
              onClick={() => runBulkAction('archive')}
              disabled={loading || selectedIds.length === 0}
              style={{ marginLeft: '0.5rem', borderColor: 'rgba(248,113,113,.5)', color: '#fecaca' }}
            >
              Secilileri Arsivle ({selectedIds.length})
            </button>
            <button
              onClick={() => runBulkAction('delete')}
              disabled={loading || selectedIds.length === 0}
              style={{ marginLeft: '0.5rem', borderColor: 'rgba(239,68,68,.7)', color: '#fecaca' }}
            >
              Secilileri Kalici Sil ({selectedIds.length})
            </button>
          </div>
        </div>

        {error ? (
          <div className="card error">
            <div className="title">Hata</div>
            <pre>{error}</pre>
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
            <pre style={{ margin: 0 }}>{message}</pre>
          </div>
        ) : null}
        {undoActive ? (
          <div className="card" style={{ marginBottom: '0.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
              <div>
                Son islem geri alinabilir. Kalan sure: <strong>{undoRemainingSec}s</strong>
              </div>
              <button onClick={runUndo}>Son Islemi Geri Al</button>
            </div>
          </div>
        ) : null}
        {bulkResults && bulkResults.length > 0 ? (
          <div className="card" style={{ marginBottom: '0.75rem' }}>
            <div className="title">Toplu Islem Sonucu</div>
            <div style={{ maxHeight: '220px', overflowY: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead>
                  <tr>
                    <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.4rem' }}>Ilan</th>
                    <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.4rem' }}>Durum</th>
                    <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.4rem' }}>Detay</th>
                  </tr>
                </thead>
                <tbody>
                  {bulkResults.map((r) => (
                    <tr key={`${r.id}-${r.ok ? 'ok' : 'fail'}`}>
                      <td style={{ padding: '0.4rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                        <div>{r.title}</div>
                        <div style={{ color: '#9ca3af', fontSize: '0.82rem' }}><code>{r.id}</code></div>
                      </td>
                      <td style={{ padding: '0.4rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                        {r.ok ? 'Basarili' : 'Hatali'}
                      </td>
                      <td style={{ padding: '0.4rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{r.message}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        ) : null}

        {!error && items.length === 0 ? <p>Ilan kaydi bulunamadi.</p> : null}
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
                      onChange={(e) => setSelectedIds(e.target.checked ? items.map((x: any) => String(x?.id || '')) : [])}
                    />
                  </th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Ilan</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Firma</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Durum</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Guncelleme</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Islemler</th>
                </tr>
              </thead>
              <tbody>
                {items.map((row: any, idx: number) => (
                  <tr key={String(row?.id || idx)}>
                    <td style={{ textAlign: 'center', padding: '0.6rem 0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <input
                        type="checkbox"
                        style={bulkCheckStyle}
                        checked={selectedIds.includes(String(row?.id || ''))}
                        onChange={(e) =>
                          setSelectedIds((prev) =>
                            e.target.checked
                              ? Array.from(new Set([...prev, String(row?.id || '')]))
                              : prev.filter((id) => id !== String(row?.id || ''))
                          )
                        }
                      />
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <div style={{ fontWeight: 600 }}>{row?.title || '-'}</div>
                      <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}><code>{row?.id || '-'}</code></div>
                      <div style={{ color: '#9ca3af', fontSize: '0.84rem', marginTop: '0.2rem' }}>
                        Kategori: <strong>{row?.category_title || '-'}</strong> (<code>{row?.category_id || '-'}</code>) | Fiyat: <strong>{fmtPrice(row?.price_amount, row?.currency)}</strong> | Olusturma: {fmtDate(row?.created_at)}
                      </div>
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <div style={{ fontWeight: 600 }}>{row?.tenant_name || row?.tenant_slug || '-'}</div>
                      <div style={{ color: '#9ca3af', fontSize: '0.86rem' }}>
                        <code>{row?.tenant_slug || '-'}</code>
                      </div>
                      <div style={{ color: '#9ca3af', fontSize: '0.82rem' }}>
                        <code>{row?.tenant_id || '-'}</code>
                      </div>
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      {STATUS_TR[String(row?.status || '')] || String(row?.status || '-')}
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      {fmtDate(row?.updated_at || row?.created_at)}
                    </td>
                    <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                      <div style={{ display: 'flex', gap: '0.45rem', flexWrap: 'wrap' }}>
                        <button
                          onClick={() => runListingAction(row, 'publish')}
                          disabled={savingId === String(row?.id || '') || !['draft', 'paused'].includes(String(row?.status || ''))}
                        >
                          Yayina Al
                        </button>
                        <button
                          onClick={() => runListingAction(row, 'pause')}
                          disabled={savingId === String(row?.id || '') || String(row?.status || '') !== 'published'}
                        >
                          Durdur
                        </button>
                        <button
                          onClick={() => runListingAction(row, 'archive')}
                          disabled={savingId === String(row?.id || '') || !['draft', 'paused'].includes(String(row?.status || ''))}
                          style={{ borderColor: 'rgba(248,113,113,.5)', color: '#fecaca' }}
                        >
                          Arsivle
                        </button>
                        <button
                          onClick={() => runListingAction(row, 'delete')}
                          disabled={savingId === String(row?.id || '')}
                          style={{ borderColor: 'rgba(239,68,68,.7)', color: '#fecaca' }}
                        >
                          Kalici Sil
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
