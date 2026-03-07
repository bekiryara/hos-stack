import React from 'react';
import {
  adminCategoriesOverview,
  adminCategoriesTree,
  adminCategoryContracts,
  adminCategoryHealth,
  adminCategoryMappings,
  adminCategoryListingStats,
} from '../api/adminClient';
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

type CategoryTab = 'genel' | 'agac';
type DetailTab = 'durum' | 'sema' | 'attribute' | 'eslesme';
type HealthStatus = 'pass' | 'warn' | 'fail' | 'info';

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

function healthColor(status: HealthStatus | string | undefined): string {
  if (status === 'pass') return '#86efac';
  if (status === 'warn') return '#fde68a';
  if (status === 'fail') return '#fca5a5';
  if (status === 'info') return '#93c5fd';
  return '#9ca3af';
}

function healthLabel(status: HealthStatus | string | undefined): string {
  if (status === 'pass') return 'Gecer';
  if (status === 'warn') return 'Uyari';
  if (status === 'fail') return 'Kritik';
  if (status === 'info') return 'Bilgi';
  return '-';
}

function healthValue(value: unknown): string {
  if (value == null) return '-';
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return JSON.stringify(value);
}

function healthSourceLabel(value: unknown): string {
  const src = String(value || '').trim().toLowerCase();
  if (!src) return '-';
  if (src === 'pazar_api') return 'Pazar API';
  if (src === 'dataset_manifest') return 'SSOT + Manifest';
  if (src === 'dataset_manifest+pazar_db') return 'SSOT + Manifest + Pazar Veritabani';
  return String(value);
}

function formatDateTimeTr(value: unknown): string {
  const raw = String(value || '').trim();
  if (!raw) return '-';
  const d = new Date(raw);
  if (!Number.isFinite(d.getTime())) return raw;
  return d.toLocaleString('tr-TR', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });
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
                <span style={{ color: '#9ca3af', marginRight: '0.35rem' }}>{isExpanded ? 'v' : '>'}</span>
              ) : (
                <span style={{ color: '#9ca3af', marginRight: '0.35rem' }}>*</span>
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
  const [detailTab, setDetailTab] = React.useState<DetailTab>('durum');

  const [overview, setOverview] = React.useState<any>(null);
  const [tree, setTree] = React.useState<CategoryNode[]>([]);
  const [selectedNode, setSelectedNode] = React.useState<CategoryNode | null>(null);
  const [expandedIds, setExpandedIds] = React.useState<Set<string>>(new Set());

  const [treeQ, setTreeQ] = React.useState('');
  const [treeStatus, setTreeStatus] = React.useState<'all' | 'active' | 'inactive'>('all');

  const [listingStatsLoading, setListingStatsLoading] = React.useState(false);
  const [listingStatsError, setListingStatsError] = React.useState<string | null>(null);
  const [listingStats, setListingStats] = React.useState<any>(null);

  const [contractsLoading, setContractsLoading] = React.useState(false);
  const [contractsError, setContractsError] = React.useState<string | null>(null);
  const [contracts, setContracts] = React.useState<any>(null);

  const [mappingLoading, setMappingLoading] = React.useState(false);
  const [mappingError, setMappingError] = React.useState<string | null>(null);
  const [selectedMapping, setSelectedMapping] = React.useState<MappingRow | null>(null);
  const selectedNodeIdRef = React.useRef('');
  const [healthLoading, setHealthLoading] = React.useState(false);
  const [healthError, setHealthError] = React.useState<string | null>(null);
  const [health, setHealth] = React.useState<any>(null);

  React.useEffect(() => {
    selectedNodeIdRef.current = String(selectedNode?.id || '').trim();
  }, [selectedNode?.id]);

  const loadHealth = React.useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setHealth(null);
      setHealthError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }
    setHealthLoading(true);
    setHealthError(null);
    try {
      const out = await adminCategoryHealth(token);
      setHealth(out || null);
    } catch (e: any) {
      setHealth(null);
      setHealthError(trAdminError(e?.body?.error || e?.message, 'Kategori saglik verisi alinamadi'));
    } finally {
      setHealthLoading(false);
    }
  }, []);

  const load = React.useCallback(async () => {
    const token = localStorage.getItem('hos_admin_token') || '';
    if (!token) {
      setError('Oturum bulunamadi. Once Kontrol Merkezi ekranindan giris yapin.');
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const [o, t] = await Promise.all([
        adminCategoriesOverview(token),
        adminCategoriesTree(token, { q: treeQ || undefined, status: treeStatus }),
      ]);
      setOverview(o || null);
      const nextTree = Array.isArray(t?.tree) ? t.tree : [];
      setTree(nextTree);
      // Agac acik/kapali durumunu koru; secim degisince veya yenilemede sifirlama.

      // Secili kategori agacta hala varsa koru, yoksa temizle
      const prevId = selectedNodeIdRef.current;
      if (prevId) {
        const ids = new Set(collectTreeIds(nextTree, []));
        if (!ids.has(prevId)) {
          setSelectedNode(null);
          setListingStats(null);
          setContracts(null);
          setSelectedMapping(null);
        }
      }
    } catch (e: any) {
      setError(trAdminError(e?.body?.error || e?.message, 'Kategori verileri alinamadi'));
    } finally {
      setLoading(false);
    }
  }, [treeQ, treeStatus]);

  React.useEffect(() => {
    void load();
  }, [load]);

  React.useEffect(() => {
    void loadHealth();
  }, [loadHealth]);

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
    const token = localStorage.getItem('hos_admin_token') || '';
    const categoryId = String(selectedNode?.id || '').trim();
    if (!token || !categoryId) {
      setContracts(null);
      setContractsError(null);
      setContractsLoading(false);
      return;
    }

    let cancelled = false;
    setContractsLoading(true);
    setContractsError(null);
    (async () => {
      try {
        const out = await adminCategoryContracts(token, categoryId);
        if (!cancelled) setContracts(out || null);
      } catch (e: any) {
        if (!cancelled) {
          setContracts(null);
          setContractsError(trAdminError(e?.body?.error || e?.message, 'Kategori sema bilgisi alinamadi'));
        }
      } finally {
        if (!cancelled) setContractsLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [selectedNode?.id]);

  React.useEffect(() => {
    const token = localStorage.getItem('hos_admin_token') || '';
    const categoryId = String(selectedNode?.id || '').trim();
    if (!token || !categoryId) {
      setSelectedMapping(null);
      setMappingError(null);
      setMappingLoading(false);
      return;
    }

    let cancelled = false;
    setMappingLoading(true);
    setMappingError(null);
    (async () => {
      try {
        const out = await adminCategoryMappings(token, { q: categoryId, mapping: 'all', page: 1, per_page: 10 });
        const items = Array.isArray(out?.items) ? out.items : [];
        const exact = items.find((x: any) => String(x?.internal_category_id || '') === categoryId) || null;
        if (!cancelled) setSelectedMapping(exact);
      } catch (e: any) {
        if (!cancelled) {
          setSelectedMapping(null);
          setMappingError(trAdminError(e?.body?.error || e?.message, 'Eslesme bilgisi alinamadi'));
        }
      } finally {
        if (!cancelled) setMappingLoading(false);
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
  const hasFilterRows = Array.isArray(contracts?.filter_schema?.filters) && contracts.filter_schema.filters.length > 0;

  const handleToggleExpand = React.useCallback((id: string) => {
    setExpandedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const handleRefresh = React.useCallback(async () => {
    await Promise.all([load(), loadHealth()]);
  }, [load, loadHealth]);

  return (
    <AdminLayout title="Kategori Yonetimi">
      <div className="card">
        <div className="title">Kategori Kontrol Merkezi</div>
        <div style={{ marginBottom: '0.75rem' }}>
          <button onClick={handleRefresh} disabled={loading || healthLoading}>
            {loading || healthLoading ? 'Yukleniyor...' : 'Yenile'}
          </button>
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
          <button className={activeTab === 'genel' ? 'admin-tab-btn active' : 'admin-tab-btn'} type="button" onClick={() => setActiveTab('genel')}>
            Genel
          </button>
          <button className={activeTab === 'agac' ? 'admin-tab-btn active' : 'admin-tab-btn'} type="button" onClick={() => setActiveTab('agac')}>
            Agac
          </button>
        </div>
      </div>

      {activeTab === 'genel' ? (
        <div className="card">
          <div className="title">Genel Durum</div>
          {healthLoading ? <p style={{ margin: 0 }}>Kategori sagligi yukleniyor...</p> : null}
          {healthError ? <p style={{ margin: 0 }}>{healthError}</p> : null}
          {!healthLoading && !healthError ? (
            <>
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))',
                  gap: '0.6rem',
                  marginBottom: '0.7rem',
                }}
              >
                <div className="card" style={{ padding: '0.6rem' }}>
                  <div>Genel Sonuc</div>
                  <strong style={{ color: healthColor(health?.overall_status) }}>{healthLabel(health?.overall_status)}</strong>
                </div>
                <div className="card" style={{ padding: '0.6rem' }}>
                  <div>Gecer</div>
                  <strong>{health?.summary?.pass ?? 0}</strong>
                </div>
                <div className="card" style={{ padding: '0.6rem' }}>
                  <div>Uyari</div>
                  <strong>{health?.summary?.warn ?? 0}</strong>
                </div>
                <div className="card" style={{ padding: '0.6rem' }}>
                  <div>Kritik</div>
                  <strong>{health?.summary?.fail ?? 0}</strong>
                </div>
                <div className="card" style={{ padding: '0.6rem' }}>
                  <div>Manifest Tarihi</div>
                  <strong>{formatDateTimeTr(health?.manifest_generated_at)}</strong>
                </div>
              </div>

              {Array.isArray(health?.sections) ? (
                <div style={{ display: 'grid', gap: '0.7rem' }}>
                  {health.sections.map((section: any, idx: number) => (
                    <div key={String(section?.key || idx)} className="card" style={{ padding: '0.6rem' }}>
                      <div className="title" style={{ marginBottom: '0.4rem' }}>{String(section?.label || section?.key || '-')}</div>
                      {!Array.isArray(section?.metrics) || section.metrics.length === 0 ? (
                        <p style={{ margin: 0 }}>Metrik yok.</p>
                      ) : (
                        <div style={{ display: 'grid', gap: '0.5rem' }}>
                          {section.metrics.map((metric: any, mIdx: number) => (
                            <div
                              key={String(metric?.key || mIdx)}
                              style={{
                                border: '1px solid rgba(148,163,184,0.25)',
                                borderRadius: '8px',
                                padding: '0.5rem',
                              }}
                            >
                              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.5rem' }}>
                                <strong>{String(metric?.label || metric?.key || '-')}</strong>
                                <span style={{ color: healthColor(metric?.status) }}>{healthLabel(metric?.status)}</span>
                              </div>
                              <div style={{ marginTop: '0.2rem' }}>
                                <strong>Deger:</strong> {healthValue(metric?.value)}
                              </div>
                              {metric?.source ? (
                                <div style={{ color: '#9ca3af', marginTop: '0.2rem' }}>
                                  Kaynak: {healthSourceLabel(metric.source)}
                                </div>
                              ) : null}
                              {metric?.reason ? (
                                <div style={{ color: '#fcd34d', marginTop: '0.2rem' }}>
                                  Neden: {String(metric.reason)}
                                </div>
                              ) : null}
                              {Array.isArray(metric?.details?.samples) && metric.details.samples.length > 0 ? (
                                <div style={{ color: '#9ca3af', marginTop: '0.25rem' }}>
                                  Ornekler: {metric.details.samples
                                    .slice(0, 3)
                                    .map((s: any) => `${String(s?.listing_id || '-')}:${Array.isArray(s?.unknown_keys) ? s.unknown_keys.join(',') : '-'}`)
                                    .join(' | ')}
                                </div>
                              ) : null}
                              {metric?.threshold ? (
                                <div style={{ color: '#9ca3af', marginTop: '0.2rem' }}>
                                  Hedef: {String(metric.threshold)}
                                </div>
                              ) : null}
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              ) : (
                <p style={{ margin: 0, color: '#9ca3af' }}>Saglik metrikleri bulunamadi.</p>
              )}
            </>
          ) : null}
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

          <div style={{ display: 'grid', gridTemplateColumns: 'minmax(320px, 1fr) minmax(380px, 1.2fr)', gap: '0.75rem' }}>
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
                  <div className="card" style={{ padding: '0.45rem', marginBottom: '0.65rem' }}>
                    <div style={{ display: 'flex', gap: '0.45rem', flexWrap: 'wrap' }}>
                      <button className={detailTab === 'durum' ? 'admin-tab-btn active' : 'admin-tab-btn'} type="button" onClick={() => setDetailTab('durum')}>
                        Durum
                      </button>
                      <button className={detailTab === 'sema' ? 'admin-tab-btn active' : 'admin-tab-btn'} type="button" onClick={() => setDetailTab('sema')}>
                        Sema
                      </button>
                      <button className={detailTab === 'attribute' ? 'admin-tab-btn active' : 'admin-tab-btn'} type="button" onClick={() => setDetailTab('attribute')}>
                        Attribute
                      </button>
                      <button className={detailTab === 'eslesme' ? 'admin-tab-btn active' : 'admin-tab-btn'} type="button" onClick={() => setDetailTab('eslesme')}>
                        Eslesme
                      </button>
                    </div>
                  </div>

                  {detailTab === 'durum' ? (
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
                  ) : null}

                  {detailTab === 'sema' ? (
                    <>
                      {contractsLoading ? <p>Sema yukleniyor...</p> : null}
                      {contractsError ? <p>{contractsError}</p> : null}
                      {!contractsLoading && !contractsError ? (
                        <div style={{ display: 'grid', gap: '0.6rem' }}>
                          <div className="card" style={{ padding: '0.6rem' }}>
                            <div><strong>Kategori:</strong> {selectedNode?.title || '-'} (<code>{String(selectedNode?.id || '-')}</code>)</div>
                            <div><strong>Varsayilan Varyant:</strong> {String(contracts?.intent_schema?.default_offer_variant || '-')}</div>
                            <div>
                              <strong>Islem Modlari:</strong>{' '}
                              {Array.isArray(contracts?.intent_schema?.allowed_transaction_modes)
                                ? contracts.intent_schema.allowed_transaction_modes.join(', ')
                                : '-'}
                            </div>
                            <div>
                              <strong>Offer Variants:</strong>{' '}
                              {Array.isArray(contracts?.intent_schema?.offer_variants) ? contracts.intent_schema.offer_variants.length : 0}
                            </div>
                          </div>
                          <details>
                            <summary>Intent Semasi (Ham)</summary>
                            <pre style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                              {JSON.stringify(contracts?.intent_schema ?? {}, null, 2)}
                            </pre>
                          </details>
                        </div>
                      ) : null}
                    </>
                  ) : null}

                  {detailTab === 'attribute' ? (
                    <>
                      {contractsLoading ? <p>Attribute yukleniyor...</p> : null}
                      {contractsError ? <p>{contractsError}</p> : null}
                      {!contractsLoading && !contractsError ? (
                        <>
                          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: '0.6rem', marginBottom: '0.7rem' }}>
                            <div className="card" style={{ padding: '0.6rem' }}><div>Toplam</div><strong>{contracts?.attribute_summary?.total ?? 0}</strong></div>
                            <div className="card" style={{ padding: '0.6rem' }}><div>Zorunlu</div><strong>{contracts?.attribute_summary?.required ?? 0}</strong></div>
                            <div className="card" style={{ padding: '0.6rem' }}><div>Opsiyonel</div><strong>{contracts?.attribute_summary?.optional ?? 0}</strong></div>
                            <div className="card" style={{ padding: '0.6rem' }}><div>Secenekli</div><strong>{contracts?.attribute_summary?.with_options ?? 0}</strong></div>
                          </div>
                          <div style={{ overflowX: 'auto' }}>
                            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                              <thead>
                                <tr>
                                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Key</th>
                                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Baslik</th>
                                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Tip</th>
                                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Zorunlu</th>
                                  <th style={{ textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.15)', padding: '0.45rem' }}>Secenek</th>
                                </tr>
                              </thead>
                              <tbody>
                                {!hasFilterRows ? (
                                  <tr>
                                    <td colSpan={5} style={{ padding: '0.6rem' }}>Attribute bulunamadi.</td>
                                  </tr>
                                ) : (
                                  (contracts.filter_schema.filters as any[]).map((f: any, idx: number) => (
                                    <tr key={String(f?.key || idx)}>
                                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}><code>{String(f?.key || '-')}</code></td>
                                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>
                                        {String(f?.title || f?.label || f?.description || f?.key || '-')}
                                      </td>
                                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{String(f?.type || '-')}</td>
                                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{f?.required ? 'Evet' : 'Hayir'}</td>
                                      <td style={{ padding: '0.45rem', borderBottom: '1px solid rgba(255,255,255,.08)' }}>{Array.isArray(f?.rules?.options) ? f.rules.options.length : 0}</td>
                                    </tr>
                                  ))
                                )}
                              </tbody>
                            </table>
                          </div>
                          <details style={{ marginTop: '0.7rem' }}>
                            <summary>Attribute Semasi (Ham)</summary>
                            <pre style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                              {JSON.stringify(contracts?.filter_schema ?? {}, null, 2)}
                            </pre>
                          </details>
                        </>
                      ) : null}
                    </>
                  ) : null}

                  {detailTab === 'eslesme' ? (
                    <>
                      {mappingLoading ? <p>Eslesme bilgisi yukleniyor...</p> : null}
                      {mappingError ? <p>{mappingError}</p> : null}
                      {!mappingLoading && !mappingError ? (
                        <div className="card" style={{ padding: '0.6rem' }}>
                          {!selectedMapping ? (
                            <p style={{ margin: 0 }}>Bu kategori icin eslesme kaydi bulunamadi.</p>
                          ) : (
                            <div style={{ display: 'grid', gap: '0.45rem' }}>
                              <div><strong>Kategori:</strong> {selectedMapping.title || '-'}</div>
                              <div><strong>Internal ID:</strong> <code>{selectedMapping.internal_category_id || '-'}</code></div>
                              <div><strong>Canonical ID:</strong> <code>{selectedMapping.canonical_category_id || '-'}</code></div>
                              <div><strong>Slug:</strong> {selectedMapping.slug || '-'}</div>
                              <div><strong>Dis Eslesme:</strong> {selectedMapping.external_source ? `${selectedMapping.external_source}:${selectedMapping.external_id || '-'}` : '-'}</div>
                              <div><strong>Menu Kullanim:</strong> {selectedMapping.menu_placements ?? 0}</div>
                              <div><strong>Durum:</strong> {selectedMapping.status || '-'}</div>
                            </div>
                          )}
                        </div>
                      ) : null}
                    </>
                  ) : null}
                </>
              )}
            </div>
          </div>
        </div>
      ) : null}
    </AdminLayout>
  );
}
