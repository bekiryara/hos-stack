import React, { useCallback, useEffect, useState } from 'react';
import { adminAudit } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';
import { trAdminError } from '../utils/opsSafety';

export function AuditPage() {
  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState('');
  const [action, setAction] = useState('');
  const [actor, setActor] = useState('');
  const [tenant, setTenant] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');

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
      const out = await adminAudit(token, { limit: 200, q, action, actor, tenant, from, to });
      const next = Array.isArray(out?.items) ? out.items : Array.isArray(out) ? out : [];
      setItems(next);
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Denetim kayitlari yuklenemedi'));
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, [q, action, actor, tenant, from, to]);

  useEffect(() => {
    load();
  }, [load]);

  function resetFilters() {
    setQ('');
    setAction('');
    setActor('');
    setTenant('');
    setFrom('');
    setTo('');
  }

  function exportCsv() {
    const rows = items.map((row: any) => ({
      created_at: row.created_at || '',
      action: row.action || '',
      actor_user_id: row.actor_user_id || '',
      tenant_slug: row.tenant_slug || row.tenant_id || '',
      metadata: row.metadata ? JSON.stringify(row.metadata) : '',
    }));
    const headers = ['created_at', 'action', 'actor_user_id', 'tenant_slug', 'metadata'];
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
        <div style={{ display: 'grid', gap: '0.5rem', marginBottom: '0.75rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: '0.5rem' }}>
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Genel arama" />
            <input value={action} onChange={(e) => setAction(e.target.value)} placeholder="Islem (action)" />
            <input value={actor} onChange={(e) => setActor(e.target.value)} placeholder="Islem yapan (actor)" />
            <input value={tenant} onChange={(e) => setTenant(e.target.value)} placeholder="Firma (slug)" />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: '0.5rem' }}>
            <input type="datetime-local" value={from} onChange={(e) => setFrom(e.target.value)} />
            <input type="datetime-local" value={to} onChange={(e) => setTo(e.target.value)} />
            <div />
            <div />
          </div>
        </div>
        <div style={{ marginBottom: '0.75rem', display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
          <button onClick={load} disabled={loading}>
            {loading ? 'Yenileniyor...' : 'Yenile'}
          </button>
          <button onClick={resetFilters} disabled={loading}>
            Filtreyi Sifirla
          </button>
          <button onClick={exportCsv} disabled={items.length === 0}>
            CSV Indir
          </button>
        </div>
        {error ? (
          <div className="card error">
            <div className="title">Hata</div>
            <pre>{String(error)}</pre>
          </div>
        ) : null}
        {!error && items.length === 0 ? <p>Denetim kaydi bulunamadi.</p> : null}
        {items.length > 0 ? (
          <div style={{ display: 'grid', gap: '0.6rem' }}>
            {items.map((row: any) => (
              <div key={row.id} className="card" style={{ padding: '0.6rem 0.8rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.75rem', flexWrap: 'wrap' }}>
                  <strong>{row.action || '-'}</strong>
                  <span style={{ color: '#9ca3af' }}>{row.created_at || '-'}</span>
                </div>
                <div style={{ fontSize: '0.9rem', marginTop: '0.35rem' }}>
                  islem yapan: <code>{row.actor_user_id || '-'}</code>
                </div>
                <div style={{ fontSize: '0.9rem', marginTop: '0.25rem' }}>
                  firma: <code>{row.tenant_slug || row.tenant_id || '-'}</code>
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
