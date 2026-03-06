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
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
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
      setError(e?.body?.error || e?.message || 'Denetim kayitlari yuklenemedi');
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <AdminLayout title="Denetim">
      <div className="card">
        <div className="title">Denetim Kayitlari</div>
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
