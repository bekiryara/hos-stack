import React from 'react';
import { adminCategoriesOverview, adminCategoriesTree, adminCategoryMappings, adminCategoryListingStats } from '../api/adminClient';
import { AdminLayout } from '../layout/AdminLayout';
import { trAdminError } from '../utils/opsSafety';

type CategoryNode = {
  id?: string;
  title?: string;
  slug?: string;
  status?: string;
  parent_id?: string | null;
  canonical_category_id?: string | null;
  children?: CategoryNode[];
};

type MappingRow = {
  internal_category_id: string;
  canonical_category_id: string;
  slug: string;
  title: string;
  status: string;
  external_source: string | null;
  external_id: string | null;
  menu_placements: number;
};

type CategoryTab = 'genel' | 'agac' | 'eslesmeler';

function countTree(nodes: CategoryNode[]): number {
  let total = 0;
  for (const node of nodes) {
    total += 1;
    total += countTree(Array.isArray(node?.children) ? node.children : []);
  }
  return total;
}

function collectTreeIds(nodes: CategoryNode[], out: string[] = []): string[] {
  for (const node of nodes) {
    const id = String(node?.id || '').trim();
    if (id) out.push(id);
    const children = Array.isArray(node?.children) ? node.children : [];
    if (children.length > 0) collectTreeIds(children, out);
  }
  return out;
}

function CategoryTree({
  nodes,
  selectedId,
  expandedIds,
  onToggleExpand,
  onSelect,
}: {
  nodes: CategoryNode[];
  selectedId: string;
  expandedIds: Set<string>;
  onToggleExpand: (id: string) => void;
  onSelect: (node: CategoryNode) => void;
}) {
  if (!Array.isArray(nodes) || nodes.length === 0) return null;

  return (
    <ul style={{ listStyle: 'none', margin: 0, paddingLeft: '1rem' }}>
      {nodes.map((node, idx) => {
        const id = String(node?.id || `${idx}`);
        const selected = selectedId === id;
        const status = String(node?.status || '');
        const children = Array.isArray(node?.children) ? node.children : [];
        const hasChildren = children.length > 0;
        const isExpanded = expandedIds.has(id);
        return (
          <li key={id} style={{ marginBottom: '0.35rem' }}>
            <button
              type="button"
              onClick={() => {
                onSelect(node);
                if (hasChildren) onToggleExpand(id);
              }}
              style={{
                width: '100%',
                textAlign: 'left',
                background: selected ? 'rgba(96, 165, 250, 0.15)' : 'transparent',
                color: '#e5e7eb',
                border: '1px solid rgba(148,163,184,0.25)',
                borderRadius: '8px',
                padding: '0.38rem 0.5rem',
                cursor: 'pointer',
              }}
            >
              {hasChildren ? (
                <span style={{ color: '#9ca3af', marginRight: '0.35rem' }}>
                  {isExpanded ? '▾' : '▸'}
                </span>
              ) : (
                <span style={{ color: '#9ca3af', marginRight: '0.35rem' }}>•</span>
              )}
              <strong>{node?.title || '-'}</strong>{' '}
              <span style={{ color: '#9ca3af' }}>({id})</span>{' '}
              <span style={{ color: status === 'active' ? '#86efac' : '#fca5a5' }}>| {status || '-'}</span>
            </button>
            {hasChildren && isExpanded ? (
              <CategoryTree
                nodes={children}
                selectedId={selectedId}
                expandedIds={expandedIds}
                onToggleExpand={onToggleExpand}
                onSelect={onSelect}
              />
            ) : null}
          </li>
        );
      })}
    </ul>
  );
}

export function CategoriesPage() {
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [activeTab, setActiveTab] = React.useState<CategoryTab>('genel');

  const [overview, setOverview] = React.useState<any>(null);
  const [tree, setTree] = React.useState<CategoryNode[]>([]);
  const [selectedNode, setSelectedNode] = React.useState<CategoryNode | null>(null);
  const [expandedIds, setExpandedIds] = React.useState<Set<string>>(new Set());

  const [treeQ, setTreeQ] = React.useState('');
  const [treeStatus, setTreeStatus] = React.useState<'all' | 'active' | 'inactive'>('all');

  const [mappingQ, setMappingQ] = React.useState('');
  const [mappingType, setMappingType] = React.useState<'all' | 'mapped' | 'unmapped'>('all');
  const [mappingPage, setMappingPage] = React.useState(1);
  const [mappings, setMappings] = React.useState<MappingRow[]>([]);
  const [mappingTotal, setMappingTotal] = React.useState(0);
  const [mappingPerPage] = React.useState(25);
  const [listingStatsLoading, setListingStatsLoading] = React.useState(false);
  const [listingStatsError, setListingStatsError] = React.useState<string | null>(null);
  const [listingStats, setListingStats] = React.useState<any>(null);

  const load = React.useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const [o, t, m] = await Promise.all([
        adminCategoriesOverview(token),
        adminCategoriesTree(token, { q: treeQ || undefined, status: treeStatus }),
        adminCategoryMappings(token, {
          q: mappingQ || undefined,
          mapping: mappingType,
          page: mappingPage,
          per_page: mappingPerPage,
        }),
      ]);
      setOverview(o || null);
      const nextTree = Array.isArray(t?.tree) ? t.tree : [];
      setTree(nextTree);
      setSelectedNode(null);
      if (!treeQ.trim()) setExpandedIds(new Set());
      setMappings(Array.isArray(m?.items) ? m.items : []);
      setMappingTotal(Number(m?.total || 0));
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Kategori verileri alinamadi'));
    } finally {
      setLoading(false);
    }
  }, [mappingPage, mappingPerPage, mappingQ, mappingType, treeQ, treeStatus]);

  React.useEffect(() => {
    void load();
  }, [load]);

  React.useEffect(() => {
    const token = localStorage.getItem('hos_admin_token') || '';
    const categoryId = String(selectedNode?.id || '').trim();
    if (!token || !categoryId) {
      setListingStats(null);
      setListingStatsError(null);
      setListingStatsLoading(false);
      return;
    }

    let cancelled = false;
    setListingStatsLoading(true);
    setListingStatsError(null);
    (async () => {
      try {
        const out = await adminCategoryListingStats(token, categoryId);
        if (!cancelled) setListingStats(out || null);
      } catch (e: any) {
        if (!cancelled) {
          setListingStats(null);
          setListingStatsError(trAdminError(e?.body?.error || e?.message, 'Ilan istatistikleri alinamadi'));
        }
      } finally {
        if (!cancelled) setListingStatsLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [selectedNode?.id]);

  React.useEffect(() => {
    const query = treeQ.trim();
    if (!query) return;
    const ids = collectTreeIds(tree, []);
    setExpandedIds(new Set(ids));
  }, [tree, treeQ]);

  const treeCount = countTree(tree);
  const mappingPages = Math.max(1, Math.ceil(mappingTotal / mappingPerPage));
  const handleToggleExpand = React.useCallback((id: string) => {
    setExpandedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  return (
    <AdminLayout title="Kategori Yonetimi">
      <div className="card">
        <div className="title">Kategori Kontrol Merkezi</div>
        <div style={{ marginBottom: '0.75rem' }}>
          <button onClick={load} disabled={loading}>{loading ? 'Yukleniyor...' : 'Yenile'}</button>
        </div>
        {error ? (
          <div className="card error">
            <div className="title">Hata</div>
            <pre>{error}</pre>
          </div>
        ) : null}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: '0.6rem' }}>
          <div className="card" style={{ padding: '0.7rem' }}><div>Toplam</div><strong>{overview?.total_categories ?? 0}</strong></div>
          <div className="card" style={{ padding: '0.7rem' }}><div>Aktif</div><strong>{overview?.active_categories ?? 0}</strong></div>
          <div className="card" style={{ padding: '0.7rem' }}><div>Pasif</div><strong>{overview?.inactive_categories ?? 0}</strong></div>
          <div className="card" style={{ padding: '0.7rem' }}><div>Kok / Yaprak</div><strong>{overview?.root_categories ?? 0} / {overview?.leaf_categories ?? 0}</strong></div>
          <div className="card" style={{ padding: '0.7rem' }}><div>Trendyol Eslesen</div><strong>{overview?.trendyol_mapped_categories ?? 0}</strong></div>
          <div className="card" style={{ padding: '0.7rem' }}><div>WC Cakisimi</div><strong>{overview?.trendyol_wc_conflict_count ?? 0}</strong></div>
          <div className="card" style={{ padding: '0.7rem' }}><div>Menu Dugumu</div><strong>{overview?.menu_nodes_total ?? 0}</strong></div>
          <div className="card" style={{ padding: '0.7rem' }}><div>Menu Virtual</div><strong>{overview?.menu_virtual_nodes ?? 0}</strong></div>
        </div>
      </div>

      <div className="card" style={{ padding: '0.5rem' }}>
        <div style={{ display: 'flex', gap: '0.45rem', flexWrap: 'wrap' }}>
          <button
            className={activeTab === 'genel' ? 'admin-tab-btn active' : 'admin-tab-btn'}
            type="button"
            onClick={() => setActiveTab('genel')}
          >
            Genel
          </button>
          <button
            className={activeTab === 'agac' ? 'admin-tab-btn active' : 'admin-tab-btn'}
            type="button"
            onClick={() => setActiveTab('agac')}
          >
            Agac
          </button>
          <button
            className={activeTab === 'eslesmeler' ? 'admin-tab-btn active' : 'admin-tab-btn'}
            type="button"
            onClick={() => setActiveTab('eslesmeler')}
          >
            Eslesmeler
          </button>
        </div>
      </div>

      {activeTab === 'genel' ? (
        <div className="card">
          <div className="title">Genel Durum</div>
          <p style={{ margin: 0, color: '#9ca3af' }}>
            Bu sekme hizli kontrol icindir. Detayli inceleme icin Agac veya Eslesmeler sekmesine gecin.
          </p>
        </div>
      ) : null}

      {activeTab === 'agac' ? (
        <div className="card">
          <div className="title">Kategori Agaci</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '0.6rem', marginBottom: '0.7rem' }}>
            <label style={{ display: 'grid', gap: '0.35rem' }}>
              <span>Arama</span>
              <input value={treeQ} onChange={(e) => setTreeQ(e.target.value)} placeholder="Baslik / slug / ID" />
            </label>
            <label style={{ display: 'grid', gap: '0.35rem' }}>
              <span>Durum</span>
              <select value={treeStatus} onChange={(e) => setTreeStatus(e.target.value as 'all' | 'active' | 'inactive')}>
                <option value="all">Hepsi</option>
                <option value="active">Aktif</option>
                <option value="inactive">Pasif</option>
              </select>
            </label>
          </div>
          <div style={{ marginBottom: '0.7rem' }}>Filtrelenmis dugum: <strong>{treeCount}</strong></div>
          <div style={{ display: 'grid', gridTemplateColumns: 'minmax(320px, 1fr) minmax(320px, 1fr)', gap: '0.75rem' }}>
            <div className="card" style={{ padding: '0.6rem', maxHeight: '520px', overflowY: 'auto' }}>
              {treeCount === 0 ? (
                <p>Kategori bulunamadi.</p>
              ) : (
                <CategoryTree
                  nodes={tree}
                  selectedId={String(selectedNode?.id || '')}
                  expandedIds={expandedIds}
                  onToggleExpand={handleToggleExpand}
                  onSelect={setSelectedNode}
                />
              )}
            </div>
            <div className="card" style={{ padding: '0.6rem' }}>
              <div className="title" style={{ marginBottom: '0.4rem' }}>Kategori Detayi</div>
              {!selectedNode ? (
                <p>Detay gormek icin soldan bir kategori secin.</p>
              ) : (
                <>
                  <div style={{ display: 'grid', gap: '0.45rem' }}>
                    <div><strong>Baslik:</strong> {selectedNode?.title || '-'}</div>
                    <div><strong>ID:</strong> <code>{String(selectedNode?.id || '-')}</code></div>
                    <div><strong>Slug:</strong> {selectedNode?.slug || '-'}</div>
                    <div><strong>Durum:</strong> {selectedNode?.status || '-'}</div>
                    <div><strong>Parent ID:</strong> {selectedNode?.parent_id || '-'}</div>
                    <div><strong>Canonical ID:</strong> {selectedNode?.canonical_category_id || '-'}</div>
                  </div>
                  <div className="card" style={{ marginTop: '0.7rem', padding: '0.6rem' }}>
                    <div className="title" style={{ marginBottom: '0.4rem' }}>Bagli Ilanlar</div>
                    {listingStatsLoading ? <p style={{ margin: 0 }}>Istatistik yukleniyor...</p> : null}
                    {listingStatsError ? <p style={{ margin: 0 }}>{listingStatsError}</p> : null}
                    {!listingStatsLoading && !listingStatsError ? (
                      <div style={{ display: 'grid', gap: '0.35rem' }}>
                        <div><strong>Alt kategori sayisi:</strong> {listingStats?.subtree_category_count ?? 0}</div>
                        <div><strong>Menu kullanim noktasi:</strong> {listingStats?.menu_placements_direct ?? 0} (bu kategori) / {listingStats?.menu_placements_subtree ?? 0} (alt dallar dahil)</div>
                        <div><strong>Bu kategori:</strong> {listingStats?.direct_total ?? 0}</div>
                        <div><strong>Alt dallar dahil:</strong> {listingStats?.subtree_total ?? 0}</div>
                        <div>
                          <strong>Durum (alt dallar dahil):</strong>{' '}
                          Yayinda {listingStats?.subtree_by_status?.published ?? 0} | Taslak {listingStats?.subtree_by_status?.draft ?? 0} | Durduruldu {listingStats?.subtree_by_status?.paused ?? 0} | Arsiv {listingStats?.subtree_by_status?.archived ?? 0}
                        </div>
                      </div>
                    ) : null}
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      ) : null}

      {activeTab === 'eslesmeler' ? (
        <div className="card">
          <div className="title">Kategori Eslesmeleri</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '0.6rem', marginBottom: '0.7rem' }}>
            <label style={{ display: 'grid', gap: '0.35rem' }}>
              <span>Arama</span>
              <input
                value={mappingQ}
                onChange={(e) => {
                  setMappingQ(e.target.value);
                  setMappingPage(1);
                }}
                placeholder="Baslik / slug / kategori ID / dis ID"
              />
            </label>
            <label style={{ display: 'grid', gap: '0.35rem' }}>
              <span>Eslesme Durumu</span>
              <select
                value={mappingType}
                onChange={(e) => {
                  setMappingType(e.target.value as 'all' | 'mapped' | 'unmapped');
                  setMappingPage(1);
                }}
              >
                <option value="all">Hepsi</option>
                <option value="mapped">Eslesmis</option>
                <option value="unmapped">Eslesmemis</option>
              </select>
            </label>
          </div>
          <div style={{ marginBottom: '0.7rem' }}>
            Toplam kayit: <strong>{mappingTotal}</strong> | Sayfa: <strong>{mappingPage}</strong> / {mappingPages}
          </div>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Kategori</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Slug</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Dis Eslesme</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Menu</th>
                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Durum</th>
                </tr>
              </thead>
              <tbody>
                {mappings.length === 0 ? (
                  <tr>
                    <td colSpan={5} style={{ padding: '0.6rem' }}>Kayit bulunamadi.</td>
                  </tr>
                ) : (
                  mappings.map((row) => (
                    <tr key={row.internal_category_id}>
                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                        <div>{row.title || '-'}</div>
                        <div style={{ color: '#9ca3af', fontSize: '0.82rem' }}><code>{row.internal_category_id}</code></div>
                      </td>
                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.slug || '-'}</td>
                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                        {row.external_source ? `${row.external_source}:${row.external_id || '-'}` : '-'}
                      </td>
                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.menu_placements ?? 0}</td>
                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{row.status || '-'}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          <div style={{ marginTop: '0.7rem' }}>
            <button onClick={() => setMappingPage((p) => Math.max(1, p - 1))} disabled={mappingPage <= 1 || loading}>
              Onceki Sayfa
            </button>
            <button onClick={() => setMappingPage((p) => Math.min(mappingPages, p + 1))} disabled={mappingPage >= mappingPages || loading} style={{ marginLeft: '0.5rem' }}>
              Sonraki Sayfa
            </button>
          </div>
        </div>
      ) : null}
    </AdminLayout>
  );
}
