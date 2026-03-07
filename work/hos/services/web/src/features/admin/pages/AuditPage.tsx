import React, { useCallback, useEffect, useState } from 'react';
import { adminAudit } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';
import { trAdminError } from '../utils/opsSafety';

const PAGE_SIZE = 100;
const NOISE_ACTIONS = new Set(['user.login', 'user.login.admin', 'user.update.admin']);
const CRITICAL_ACTION_KEYWORDS = ['delete', 'deactivate', 'suspend', 'owner', 'role.change', 'membership.delete'];
const EXTRA_NOISE_ACTIONS = new Set(['user.login.google']);
type AuditTab = 'all' | 'listing' | 'user' | 'membership';

function toTime(v: any): number {
  const d = new Date(String(v || ''));
  return Number.isFinite(d.getTime()) ? d.getTime() : 0;
}

function isCriticalAction(action: any): boolean {
  const a = String(action || '').toLowerCase();
  return CRITICAL_ACTION_KEYWORDS.some((k) => a.includes(k));
}

function actionDomain(action: any): AuditTab | 'other' {
  const a = String(action || '').toLowerCase();
  if (a.startsWith('listing.')) return 'listing';
  if (a.startsWith('user.')) return 'user';
  if (a.startsWith('membership.')) return 'membership';
  return 'other';
}

function actionLabelTr(action: any): string {
  const a = String(action || '');
  const map: Record<string, string> = {
    'listing.lifecycle.platform': 'Ilan durum degisikligi',
    'user.role.change.platform': 'Kullanici rol degisikligi',
    'user.deactivate.platform': 'Kullanici pasife alindi',
    'user.delete.platform': 'Kullanici kalici silindi',
    'membership.update.platform': 'Uyelik guncellendi',
    'membership.deactivate.platform': 'Uyelik pasife alindi',
    'membership.delete.platform': 'Uyelik kalici silindi',
    'user.login.admin': 'Admin girisi',
  };
  return map[a] || a || '-';
}

function normalizeMeta(v: any): any {
  if (!v || typeof v !== 'object' || Array.isArray(v)) return {};
  return v;
}

function targetSummary(row: any): string | null {
  if (actionDomain(row?.action) === 'listing') return null;
  const m = normalizeMeta(row?.metadata);
  const targetUser = m.targetEmail || m.userEmail || m.targetUserId || m.userId || null;
  const targetTenant = m.tenantSlug || m.tenant_id || row?.tenant_slug || row?.tenant_id || null;
  if (!targetUser && !targetTenant) return null;
  return `hedef: ${targetUser || '-'} | firma: ${targetTenant || '-'}`;
}

function rowSummaryTr(row: any): string | null {
  const action = String(row?.action || '');
  const m = normalizeMeta(row?.metadata);

  if (action === 'listing.lifecycle.platform') {
    const listingId = String(m.listingId || '-');
    const listingTitle = String(m.listingTitle || '').trim();
    const prevStatus = String(m.prevStatus || '-');
    const nextStatus = String(m.nextStatus || '-');
    const actionTr =
      String(m.action || '') === 'pause'
        ? 'Durdur'
        : String(m.action || '') === 'publish'
          ? 'Yayina Al'
          : String(m.action || '') === 'archive'
            ? 'Arsivle'
            : String(m.action || '') === 'delete'
              ? 'Kalici Sil'
            : String(m.action || '-');
    const listingPart = listingTitle ? `${listingTitle} (${listingId})` : listingId;
    return `Ilan: ${listingPart} | Islem: ${actionTr} | Durum: ${prevStatus} -> ${nextStatus}`;
  }

  if (action.startsWith('user.')) {
    const target = String(m.targetEmail || m.userEmail || m.targetUserId || m.userId || '-');
    return `Kullanici: ${target}`;
  }

  if (action.startsWith('membership.')) {
    const target = String(m.targetEmail || m.userEmail || m.targetUserId || '-');
    const role = String(m.role || '-');
    const status = String(m.status || '-');
    return `Uyelik hedefi: ${target} | Rol: ${role} | Durum: ${status}`;
  }

  return null;
}

export function AuditPage() {
  const initialSearch = new URLSearchParams(window.location.search);
  const initialPageRaw = Number(initialSearch.get('page') || 0);
  const initialPage = Number.isFinite(initialPageRaw) && initialPageRaw > 0 ? Math.floor(initialPageRaw) : 0;
  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState(initialSearch.get('q') || '');
  const [action, setAction] = useState(initialSearch.get('action') || '');
  const [actor, setActor] = useState(initialSearch.get('actor') || '');
  const [tenant, setTenant] = useState(initialSearch.get('tenant') || '');
  const [from, setFrom] = useState(initialSearch.get('from') || '');
  const [to, setTo] = useState(initialSearch.get('to') || '');
  const [hideNoise, setHideNoise] = useState((initialSearch.get('hideNoise') || '1') !== '0');
  const [mergeRepeats, setMergeRepeats] = useState((initialSearch.get('mergeRepeats') || '1') !== '0');
  const [criticalOnly, setCriticalOnly] = useState((initialSearch.get('criticalOnly') || '0') === '1');
  const [tab, setTab] = useState<AuditTab>((initialSearch.get('tab') as AuditTab) || 'all');
  const [page, setPage] = useState(initialPage);
  const [hasMore, setHasMore] = useState(false);

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
      const out = await adminAudit(token, { limit: PAGE_SIZE, offset: page * PAGE_SIZE, q, action, actor, tenant, from, to });
      const next = Array.isArray(out?.items) ? out.items : Array.isArray(out) ? out : [];
      setItems(next);
      setHasMore(next.length === PAGE_SIZE);
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Denetim kayitlari yuklenemedi'));
      setItems([]);
      setHasMore(false);
    } finally {
      setLoading(false);
    }
  }, [q, action, actor, tenant, from, to, page]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    setPage(0);
  }, [q, action, actor, tenant, from, to, hideNoise, mergeRepeats, criticalOnly, tab]);

  useEffect(() => {
    const params = new URLSearchParams();
    if (q) params.set('q', q);
    if (action) params.set('action', action);
    if (actor) params.set('actor', actor);
    if (tenant) params.set('tenant', tenant);
    if (from) params.set('from', from);
    if (to) params.set('to', to);
    if (!hideNoise) params.set('hideNoise', '0');
    if (!mergeRepeats) params.set('mergeRepeats', '0');
    if (criticalOnly) params.set('criticalOnly', '1');
    if (tab !== 'all') params.set('tab', tab);
    if (page > 0) params.set('page', String(page));
    const nextUrl = `${window.location.pathname}${params.toString() ? `?${params.toString()}` : ''}`;
    window.history.replaceState({}, '', nextUrl);
  }, [q, action, actor, tenant, from, to, hideNoise, mergeRepeats, criticalOnly, tab, page]);

  const visibleItems = React.useMemo(() => {
    const noNoise = hideNoise ? items.filter((x: any) => !NOISE_ACTIONS.has(String(x?.action || ''))) : items;
    const byTab =
      tab === 'all'
        ? noNoise
        : noNoise.filter((x: any) => {
            const d = actionDomain(x?.action);
            return tab === d;
          });
    const filtered = criticalOnly
      ? byTab.filter((x: any) => {
          return isCriticalAction(x?.action);
        })
      : byTab;
    if (!mergeRepeats) return filtered;
    const out: any[] = [];
    for (const row of filtered) {
      const last = out[out.length - 1];
      if (!last) {
        out.push({ ...row, repeat_count: 1, first_created_at: row.created_at, last_created_at: row.created_at });
        continue;
      }
      const rowAction = String(row.action || '');
      const sameAction = String(last.action || '') === rowAction;
      const sameActor = String(last.actor_user_id || '') === String(row.actor_user_id || '');
      const sameTenant = String(last.tenant_slug || last.tenant_id || '') === String(row.tenant_slug || row.tenant_id || '');
      const sameTarget = targetSummary(last) === targetSummary(row);
      const mergeWindowMs = NOISE_ACTIONS.has(rowAction) || EXTRA_NOISE_ACTIONS.has(rowAction) ? 600000 : 120000;
      const close = Math.abs(toTime(last.created_at) - toTime(row.created_at)) <= mergeWindowMs;
      if (sameAction && sameActor && sameTenant && close) {
        last.repeat_count = (last.repeat_count || 1) + 1;
        last.last_created_at = row.created_at || last.last_created_at;
        if (sameTarget) last.metadata = last.metadata || row.metadata;
      } else {
        out.push({ ...row, repeat_count: 1, first_created_at: row.created_at, last_created_at: row.created_at });
      }
    }
    return out;
  }, [items, hideNoise, mergeRepeats, criticalOnly, tab]);

  const criticalItems = React.useMemo(
    () => visibleItems.filter((x: any) => isCriticalAction(x?.action)),
    [visibleItems]
  );

  const normalItems = React.useMemo(
    () => visibleItems.filter((x: any) => !isCriticalAction(x?.action)),
    [visibleItems]
  );

  function resetFilters() {
    setQ('');
    setAction('');
    setActor('');
    setTenant('');
    setFrom('');
    setTo('');
    setHideNoise(true);
    setMergeRepeats(true);
    setCriticalOnly(false);
    setTab('all');
    setPage(0);
  }

  function applyPreset(name: 'today' | 'critical' | 'login' | 'change') {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    const toLocalInput = (d: Date) => {
      const pad = (n: number) => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    };

    setQ('');
    setActor('');
    setTenant('');
    setFrom('');
    setTo('');
    setPage(0);

    if (name === 'today') {
      setAction('');
      setHideNoise(true);
      setCriticalOnly(false);
      setMergeRepeats(true);
      setFrom(toLocalInput(startOfDay));
      setTo(toLocalInput(now));
      return;
    }
    if (name === 'critical') {
      setAction('delete|deactivate|owner');
      setQ('delete deactivate owner');
      setHideNoise(true);
      setCriticalOnly(true);
      setMergeRepeats(false);
      return;
    }
    if (name === 'login') {
      setAction('user.login');
      setHideNoise(false);
      setCriticalOnly(false);
      setMergeRepeats(true);
      return;
    }
    setAction('update|change|membership');
    setQ('update change membership');
    setHideNoise(true);
    setCriticalOnly(false);
    setMergeRepeats(false);
  }

  function exportCsv() {
    const rows = visibleItems.map((row: any) => ({
      created_at: row.created_at || '',
      action: row.action || '',
      actor_email: row.actor_email || '',
      actor_user_id: row.actor_user_id || '',
      tenant_slug: row.tenant_slug || row.tenant_id || '',
      repeat_count: row.repeat_count || 1,
      metadata: row.metadata ? JSON.stringify(row.metadata) : '',
    }));
    const headers = ['created_at', 'action', 'actor_email', 'actor_user_id', 'tenant_slug', 'repeat_count', 'metadata'];
    const esc = (v: any) => `"${String(v ?? '').replace(/"/g, '""')}"`;
    const csv = [headers.join(','), ...rows.map((r) => headers.map((h) => esc((r as any)[h])).join(','))].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    const ts = new Date().toISOString().replace(/[:.]/g, '-');
    a.href = url;
    a.download = `admin-audit-${ts}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  return (
    <AdminLayout title="Denetim">
      <div className="card">
        <div className="title">Denetim Kayitlari</div>
        <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', marginBottom: '0.75rem' }}>
          <button onClick={() => setTab('all')} disabled={tab === 'all'}>Tum Isler</button>
          <button onClick={() => setTab('listing')} disabled={tab === 'listing'}>Ilan</button>
          <button onClick={() => setTab('user')} disabled={tab === 'user'}>Kullanici</button>
          <button onClick={() => setTab('membership')} disabled={tab === 'membership'}>Uyelik</button>
        </div>
        <div style={{ display: 'grid', gap: '0.5rem', marginBottom: '0.75rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, minmax(0, 1fr))', gap: '0.5rem' }}>
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Genel arama" />
            <input value={action} onChange={(e) => setAction(e.target.value)} placeholder="Islem kodu (ornek: listing.lifecycle.platform)" />
            <input value={actor} onChange={(e) => setActor(e.target.value)} placeholder="Islem yapan (actor)" />
            <input value={tenant} onChange={(e) => setTenant(e.target.value)} placeholder="Firma (slug)" />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: '0.5rem' }}>
            <input type="datetime-local" value={from} onChange={(e) => setFrom(e.target.value)} />
            <input type="datetime-local" value={to} onChange={(e) => setTo(e.target.value)} />
            <label style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
              <input type="checkbox" checked={hideNoise} onChange={(e) => setHideNoise(e.target.checked)} />
              Gurultuyu gizle
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
              <input type="checkbox" checked={mergeRepeats} onChange={(e) => setMergeRepeats(e.target.checked)} />
              Tekrarlari birlestir
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
              <input type="checkbox" checked={criticalOnly} onChange={(e) => setCriticalOnly(e.target.checked)} />
              Sadece kritik
            </label>
          </div>
        </div>
        <div style={{ marginBottom: '0.75rem', display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
          <button onClick={() => applyPreset('today')} disabled={loading}>
            Bugun
          </button>
          <button onClick={() => applyPreset('critical')} disabled={loading}>
            Kritik
          </button>
          <button onClick={() => applyPreset('login')} disabled={loading}>
            Login
          </button>
          <button onClick={() => applyPreset('change')} disabled={loading}>
            Degisiklik
          </button>
          <button onClick={load} disabled={loading}>
            {loading ? 'Yenileniyor...' : 'Yenile'}
          </button>
          <button onClick={resetFilters} disabled={loading}>
            Filtreyi Sifirla
          </button>
          <button onClick={exportCsv} disabled={items.length === 0}>
            CSV Indir
          </button>
          <button onClick={() => setPage((p) => Math.max(0, p - 1))} disabled={loading || page === 0}>
            Onceki Sayfa
          </button>
          <button onClick={() => setPage((p) => p + 1)} disabled={loading || !hasMore}>
            Sonraki Sayfa
          </button>
          <span style={{ color: '#9ca3af', fontSize: '0.9rem', alignSelf: 'center' }}>
            Sayfa: {page + 1}
          </span>
        </div>
        {error ? (
          <div className="card error">
            <div className="title">Hata</div>
            <pre>{String(error)}</pre>
          </div>
        ) : null}
        {!error && visibleItems.length === 0 ? <p>Denetim kaydi bulunamadi.</p> : null}
        {visibleItems.length > 0 ? (
          <div style={{ display: 'grid', gap: '0.6rem' }}>
            {criticalItems.length > 0 ? (
              <div className="card" style={{ padding: '0.7rem 0.8rem', borderColor: 'rgba(148,163,184,.28)', background: 'rgba(30,41,59,.28)' }}>
                <div style={{ fontWeight: 700, color: '#cbd5e1', marginBottom: '0.5rem' }}>
                  Kritik Kayitlar ({criticalItems.length})
                </div>
                <div style={{ display: 'grid', gap: '0.5rem' }}>
                  {criticalItems.map((row: any) => (
                    <div key={`critical-${row.id}`} className="card" style={{ padding: '0.6rem 0.7rem' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.75rem', flexWrap: 'wrap' }}>
                        <strong>
                          {actionLabelTr(row.action)}
                          {row.repeat_count > 1 ? (
                            <span style={{ marginLeft: '0.4rem', color: '#cbd5e1', fontWeight: 500 }}>x{row.repeat_count}</span>
                          ) : null}
                        </strong>
                        <span style={{ color: '#9ca3af' }}>
                          {row.created_at || '-'}
                        </span>
                      </div>
                      <div style={{ fontSize: '0.9rem', marginTop: '0.35rem' }}>
                        islem yapan: <code>{row.actor_email || row.actor_user_id || '-'}</code>
                      </div>
                      <div style={{ fontSize: '0.9rem', marginTop: '0.25rem' }}>
                        firma: <code>{row.tenant_slug || row.tenant_id || '-'}</code>
                      </div>
                      {targetSummary(row) ? (
                        <div style={{ fontSize: '0.9rem', marginTop: '0.25rem', color: '#d1d5db' }}>
                          {targetSummary(row)}
                        </div>
                      ) : null}
                      {rowSummaryTr(row) ? (
                        <div style={{ fontSize: '0.9rem', marginTop: '0.25rem', color: '#d1d5db' }}>
                          {rowSummaryTr(row)}
                        </div>
                      ) : null}
                      {row.repeat_count > 1 ? (
                          <div style={{ fontSize: '0.84rem', marginTop: '0.25rem', color: '#9ca3af' }}>
                            zaman araligi: {row.first_created_at || '-'} {'->'} {row.last_created_at || '-'}
                          </div>
                      ) : null}
                      {row.metadata ? (
                        <details style={{ marginTop: '0.4rem' }}>
                          <summary>Ham detay</summary>
                          <pre>{JSON.stringify(row.metadata, null, 2)}</pre>
                        </details>
                      ) : null}
                    </div>
                  ))}
                </div>
              </div>
            ) : null}

            {normalItems.map((row: any) => (
              <div key={row.id} className="card" style={{ padding: '0.6rem 0.8rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.75rem', flexWrap: 'wrap' }}>
                  <strong>
                    {actionLabelTr(row.action)}
                    {row.repeat_count > 1 ? (
                      <span style={{ marginLeft: '0.4rem', color: '#e8c784', fontWeight: 500 }}>x{row.repeat_count}</span>
                    ) : null}
                  </strong>
                  <span style={{ color: '#9ca3af' }}>{row.created_at || '-'}</span>
                </div>
                <div style={{ fontSize: '0.9rem', marginTop: '0.35rem' }}>
                  islem yapan: <code>{row.actor_email || row.actor_user_id || '-'}</code>
                </div>
                <div style={{ fontSize: '0.9rem', marginTop: '0.25rem' }}>
                  firma: <code>{row.tenant_slug || row.tenant_id || '-'}</code>
                </div>
                {targetSummary(row) ? (
                  <div style={{ fontSize: '0.9rem', marginTop: '0.25rem', color: '#d1d5db' }}>
                    {targetSummary(row)}
                  </div>
                ) : null}
                {rowSummaryTr(row) ? (
                  <div style={{ fontSize: '0.9rem', marginTop: '0.25rem', color: '#d1d5db' }}>
                    {rowSummaryTr(row)}
                  </div>
                ) : null}
                {row.repeat_count > 1 ? (
                  <div style={{ fontSize: '0.84rem', marginTop: '0.25rem', color: '#9ca3af' }}>
                    zaman araligi: {row.first_created_at || '-'} {'->'} {row.last_created_at || '-'}
                  </div>
                ) : null}
                {row.metadata ? (
                  <details style={{ marginTop: '0.4rem' }}>
                    <summary>Ham detay</summary>
                    <pre>{JSON.stringify(row.metadata, null, 2)}</pre>
                  </details>
                ) : null}
              </div>
            ))}
          </div>
        ) : null}
      </div>
    </AdminLayout>
  );
}
