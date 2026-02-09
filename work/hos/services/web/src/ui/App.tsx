import React, { useEffect, useMemo, useState } from 'react';
import { adminAudit, adminTenants, adminUsers, getHealth, getWorlds, hosLogin, hosMe } from '../lib/api';

export function App() {
  const route = useMemo(() => window.location.pathname || '/', []);
  const isAdminRoute =
    route.startsWith('/ui/admin/control-center') || route.startsWith('/admin') || route.startsWith('/ui/admin');

  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<any>(null);
  const [worldsLoading, setWorldsLoading] = useState(true);
  const [worlds, setWorlds] = useState<any[]>([]);
  const [worldsError, setWorldsError] = useState<any>(null);
  
  // WP-59: Demo Control Panel state
  const [demoChecks, setDemoChecks] = useState<{
    hosApi: { pass: boolean; message: string };
    worlds: { pass: boolean; message: string };
    pazar: { pass: boolean; message: string };
    messaging: { pass: boolean; message: string };
    marketplaceUi: { pass: boolean; message: string };
  }>({
    hosApi: { pass: false, message: 'Checking...' },
    worlds: { pass: false, message: 'Checking...' },
    pazar: { pass: false, message: 'Checking...' },
    messaging: { pass: false, message: 'Checking...' },
    marketplaceUi: { pass: false, message: 'Checking...' },
  });
  const [demoChecksLoading, setDemoChecksLoading] = useState(true);
  const [listingId, setListingId] = useState<string | null>(null);
  const [listingError, setListingError] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const h = await getHealth();
      setData(h);
    } catch (e) {
      setError(e);
    } finally {
      setLoading(false);
    }
  }

  async function loadWorlds() {
    setWorldsLoading(true);
    setWorldsError(null);
    try {
      const w = await getWorlds();
      setWorlds(w);
    } catch (e) {
      setWorldsError(e);
    } finally {
      setWorldsLoading(false);
    }
  }

  useEffect(() => {
    load();
    loadWorlds();
    checkDemoReadiness();
    fetchListingForMessaging();
  }, []);

  // Minimal HOS Admin Control Center (DEV-only)
  const tokenStorageKey = 'hos_admin_token';
  const [token, setToken] = useState<string>(() => localStorage.getItem(tokenStorageKey) || '');
  const [tenantSlug, setTenantSlug] = useState<string>('');
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [authBusy, setAuthBusy] = useState(false);
  const [me, setMe] = useState<any>(null);
  const [adminOut, setAdminOut] = useState<any>(null);
  const [adminErr, setAdminErr] = useState<any>(null);

  useEffect(() => {
    try {
      localStorage.setItem(tokenStorageKey, token || '');
    } catch {}
  }, [token]);

  async function adminRefreshMe() {
    setAdminErr(null);
    setAdminOut(null);
    if (!token) {
      setAdminErr(new Error('Missing token'));
      return;
    }
    try {
      const m = await hosMe(token);
      setMe(m);
      setAdminOut(m);
    } catch (e: any) {
      setAdminErr(e);
    }
  }

  async function adminDoLogin() {
    setAdminErr(null);
    setAdminOut(null);
    setAuthBusy(true);
    try {
      const resp = await hosLogin({ tenantSlug: tenantSlug || undefined, email, password });
      const t = resp?.token || resp?.access_token || resp?.jwt;
      if (!t) throw new Error('Login succeeded but no token returned');
      setToken(String(t));
      const m = await hosMe(String(t));
      setMe(m);
      setAdminOut({ login: 'ok', me: m });
    } catch (e: any) {
      setAdminErr(e);
    } finally {
      setAuthBusy(false);
    }
  }

  async function adminLoadTenants() {
    setAdminErr(null);
    setAdminOut(null);
    try {
      setAdminOut(await adminTenants(token));
    } catch (e: any) {
      setAdminErr(e);
    }
  }

  async function adminLoadUsers() {
    setAdminErr(null);
    setAdminOut(null);
    try {
      setAdminOut(await adminUsers(token));
    } catch (e: any) {
      setAdminErr(e);
    }
  }

  async function adminLoadAudit() {
    setAdminErr(null);
    setAdminOut(null);
    try {
      setAdminOut(await adminAudit(token, 50));
    } catch (e: any) {
      setAdminErr(e);
    }
  }

  if (isAdminRoute) {
    return (
      <div className="page" data-marker="hos-admin-control-center">
        <header className="top">
          <div className="brand">
            H-OS Admin <span style={{ fontSize: '0.7rem', color: '#ff6b6b', fontWeight: 'normal' }}>(DEV ONLY)</span>
          </div>
          <div className="actions">
            <a href="/" style={{ marginRight: '0.75rem' }}>
              Home
            </a>
            <a href="/api/v1/health" target="_blank" rel="noreferrer">
              /api/v1/health
            </a>
          </div>
        </header>

        <main className="main">
          <h1>Admin Control Center</h1>
          <p className="hint">
            SSOT: Admin surface lives in H-OS only. Pazar must not expose <code>/admin</code>/<code>/panel</code>.
          </p>

          <div className="card">
            <div className="title">Auth (JWT)</div>
            <div style={{ display: 'grid', gap: '0.5rem', maxWidth: 520 }}>
              <label>
                Tenant slug (optional)
                <input value={tenantSlug} onChange={(e) => setTenantSlug(e.target.value)} placeholder="acme" />
              </label>
              <label>
                Email
                <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin@acme.com" />
              </label>
              <label>
                Password
                <input
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  type="password"
                />
              </label>
              <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                <button onClick={adminDoLogin} disabled={authBusy || !email || !password}>
                  {authBusy ? 'Logging in…' : 'Login'}
                </button>
                <button onClick={adminRefreshMe} disabled={!token}>
                  /v1/me
                </button>
              </div>
              <label>
                Token (stored in localStorage: <code>{tokenStorageKey}</code>)
                <textarea
                  value={token}
                  onChange={(e) => setToken(e.target.value)}
                  placeholder="paste JWT here"
                  rows={4}
                  style={{ width: '100%' }}
                />
              </label>
              {me ? (
                <div style={{ fontSize: '0.9rem', color: '#666' }}>
                  Logged in as: <code>{me?.email || me?.sub || 'unknown'}</code>
                </div>
              ) : null}
            </div>
          </div>

          <div className="card">
            <div className="title">Admin APIs (HOS)</div>
            <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
              <button onClick={adminLoadTenants} disabled={!token}>
                GET /v1/admin/tenants
              </button>
              <button onClick={adminLoadUsers} disabled={!token}>
                GET /v1/admin/users
              </button>
              <button onClick={adminLoadAudit} disabled={!token}>
                GET /v1/admin/audit
              </button>
            </div>
            {adminErr ? (
              <div className="card error" style={{ marginTop: '0.75rem' }}>
                <div className="title">Error</div>
                <pre>{JSON.stringify({ message: adminErr?.message, status: adminErr?.status, body: adminErr?.body }, null, 2)}</pre>
              </div>
            ) : null}
            {adminOut ? (
              <div style={{ marginTop: '0.75rem' }}>
                <pre>{JSON.stringify(adminOut, null, 2)}</pre>
              </div>
            ) : null}
          </div>
        </main>
      </div>
    );
  }

  // WP-69: Removed handleEnterDemo, handleExitDemo, handleGoToDemo
  // HOS Web no longer manages auth tokens - Marketplace Web is the single auth entry

  // WP-59: Demo Control Panel checks
  async function checkDemoReadiness() {
    setDemoChecksLoading(true);
    const checks = {
      hosApi: { pass: false, message: '' },
      worlds: { pass: false, message: '' },
      pazar: { pass: false, message: '' },
      messaging: { pass: false, message: '' },
      marketplaceUi: { pass: false, message: '' },
    };

    // Check 1: HOS API reachable
    try {
      const resp = await fetch('/api/v1/world/status', { cache: 'no-store' });
      if (resp.ok) {
        const data = await resp.json();
        checks.hosApi = { pass: true, message: `HOS API: ${data.world_key || 'OK'}` };
      } else {
        checks.hosApi = { pass: false, message: `HOS API: HTTP ${resp.status}` };
      }
    } catch (e: any) {
      checks.hosApi = { pass: false, message: `HOS API: ${e.message || 'Unreachable'}` };
    }

    // Check 2: Worlds list contains marketplace + messaging ONLINE
    try {
      const w = await getWorlds();
      const marketplace = w.find((w: any) => w.world_key === 'marketplace');
      const messaging = w.find((w: any) => w.world_key === 'messaging');
      const marketplaceOk = marketplace?.availability === 'ONLINE';
      const messagingOk = messaging?.availability === 'ONLINE';
      if (marketplaceOk && messagingOk) {
        checks.worlds = { pass: true, message: 'Marketplace & Messaging: ONLINE' };
      } else {
        const missing = [];
        if (!marketplaceOk) missing.push('marketplace');
        if (!messagingOk) missing.push('messaging');
        checks.worlds = { pass: false, message: `Missing/offline: ${missing.join(', ')}` };
      }
    } catch (e: any) {
      checks.worlds = { pass: false, message: `Worlds: ${e.message || 'Unreachable'}` };
    }

    // Check 3: Pazar reachable
    try {
      const resp = await fetch('/api/marketplace/api/world/status', { cache: 'no-store' });
      if (resp.ok) {
        const data = await resp.json();
        checks.pazar = { pass: true, message: `Pazar: ${data.world_key || 'OK'}` };
      } else {
        checks.pazar = { pass: false, message: `Pazar: HTTP ${resp.status}` };
      }
    } catch (e: any) {
      checks.pazar = { pass: false, message: `Pazar: ${e.message || 'Unreachable'}` };
    }

    // Check 4: Messaging reachable through proxy
    try {
      const resp = await fetch('/api/messaging/api/world/status', { cache: 'no-store' });
      if (resp.ok) {
        const data = await resp.json();
        checks.messaging = { pass: true, message: `Messaging (proxy): ${data.world_key || 'OK'}` };
      } else {
        checks.messaging = { pass: false, message: `Messaging (proxy): HTTP ${resp.status}` };
      }
    } catch (e: any) {
      checks.messaging = { pass: false, message: `Messaging (proxy): ${e.message || 'Unreachable'}` };
    }

    // Check 5: Marketplace UI route reachable
    try {
      const resp = await fetch('/marketplace/', { cache: 'no-store' });
      if (resp.ok) {
        const text = await resp.text();
        if (text.includes('id="app"') || text.includes('Marketplace')) {
          checks.marketplaceUi = { pass: true, message: 'Marketplace UI: Reachable' };
        } else {
          checks.marketplaceUi = { pass: false, message: 'Marketplace UI: Missing marker' };
        }
      } else {
        checks.marketplaceUi = { pass: false, message: `Marketplace UI: HTTP ${resp.status}` };
      }
    } catch (e: any) {
      checks.marketplaceUi = { pass: false, message: `Marketplace UI: ${e.message || 'Unreachable'}` };
    }

    setDemoChecks(checks);
    setDemoChecksLoading(false);
  }

  // WP-59: Fetch listing for messaging link
  async function fetchListingForMessaging() {
    try {
      setListingError(null);
      const resp = await fetch('/api/marketplace/api/v1/listings?status=published&limit=1', {
        cache: 'no-store',
      });
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}`);
      }
      const data = await resp.json();
      const items = Array.isArray(data) ? data : (data.items || data.data || []);
      if (items.length > 0 && items[0].id) {
        setListingId(items[0].id);
      } else {
        // Try without status filter
        const resp2 = await fetch('/api/marketplace/api/v1/listings?limit=1', {
          cache: 'no-store',
        });
        if (resp2.ok) {
          const data2 = await resp2.json();
          const items2 = Array.isArray(data2) ? data2 : (data2.items || data2.data || []);
          if (items2.length > 0 && items2[0].id) {
            setListingId(items2[0].id);
          } else {
            setListingError('No published listing found');
          }
        } else {
          setListingError('No published listing found');
        }
      }
    } catch (e: any) {
      setListingError(e.message || 'Failed to fetch listing');
    }
  }

  // WP-69: Removed handleResetDemo - HOS Web no longer manages auth tokens

  const handleOpenMessaging = () => {
    if (listingId) {
      window.location.href = `/marketplace/listing/${listingId}/message`;
    } else {
      alert('No listing found. Please create a listing first.');
    }
  };

  return (
    <div className="page" data-marker="hos-home">
      <header className="top">
        <div className="brand">H-OS Admin <span style={{ fontSize: '0.7rem', color: '#ff6b6b', fontWeight: 'normal' }}>(DEV ONLY)</span></div>
        <div className="actions">
          <button onClick={load} disabled={loading}>
            {loading ? 'Loading…' : 'Refresh'}
          </button>
          <button onClick={loadWorlds} disabled={worldsLoading} style={{ marginLeft: '0.5rem' }}>
            {worldsLoading ? 'Loading…' : 'Refresh Worlds'}
          </button>
          <a href="/ui/admin/control-center" style={{ marginLeft: '0.75rem' }}>Admin Control Center</a>
          <a href="/api/v1/health" target="_blank" rel="noreferrer">/api/v1/health</a>
        </div>
      </header>

      <main className="main">
        <h1>Status</h1>

        {error ? (
          <div className="card error">
            <div className="title">API unreachable</div>
            <pre>{String(error?.message ?? error)}</pre>
          </div>
        ) : (
          <div className="card">
            <div className="title">API health</div>
            <pre>{JSON.stringify(data, null, 2)}</pre>
          </div>
        )}

        <h1>System Status</h1>

        <div data-marker="system-status" style={{ marginBottom: '2rem', padding: '1.5rem', border: '2px solid #ccc', borderRadius: '8px', backgroundColor: '#f9f9f9' }}>
          <div style={{ marginBottom: '1rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h2 style={{ margin: 0, fontSize: '1.5rem' }}>System Status</h2>
            <button
              onClick={checkDemoReadiness}
              disabled={demoChecksLoading}
              style={{
                padding: '0.5rem 1rem',
                fontSize: '0.875rem',
                backgroundColor: '#0066cc',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: demoChecksLoading ? 'not-allowed' : 'pointer',
              }}
            >
              {demoChecksLoading ? 'Checking...' : 'Refresh Checks'}
            </button>
          </div>

          {demoChecksLoading ? (
            <div>Loading readiness checks...</div>
          ) : (
            <div style={{ marginBottom: '1.5rem' }}>
              {[
                { key: 'hosApi', label: '1. HOS API reachable' },
                { key: 'worlds', label: '2. Worlds (marketplace + messaging ONLINE)' },
                { key: 'pazar', label: '3. Pazar reachable' },
                { key: 'messaging', label: '4. Messaging reachable (proxy)' },
                { key: 'marketplaceUi', label: '5. Marketplace UI route reachable' },
              ].map(({ key, label }) => {
                const check = demoChecks[key as keyof typeof demoChecks];
                const isPass = check.pass;
                return (
                  <div
                    key={key}
                    style={{
                      marginBottom: '0.75rem',
                      padding: '0.75rem',
                      backgroundColor: isPass ? '#d4edda' : '#f8d7da',
                      border: `1px solid ${isPass ? '#c3e6cb' : '#f5c6cb'}`,
                      borderRadius: '4px',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <strong>{label}</strong>
                      <div style={{ fontSize: '0.875rem', color: '#666', marginTop: '0.25rem' }}>
                        {check.message}
                      </div>
                    </div>
                    <div
                      style={{
                        padding: '0.25rem 0.75rem',
                        borderRadius: '4px',
                        backgroundColor: isPass ? '#28a745' : '#dc3545',
                        color: 'white',
                        fontSize: '0.875rem',
                        fontWeight: 'bold',
                      }}
                    >
                      {isPass ? 'PASS' : 'FAIL'}
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {!demoChecksLoading && (
            <div
              data-marker={
                Object.values(demoChecks).every((c) => c.pass)
                  ? 'demo-ready-pass'
                  : 'demo-ready-fail'
              }
              style={{
                marginBottom: '1.5rem',
                padding: '1rem',
                backgroundColor: Object.values(demoChecks).every((c) => c.pass) ? '#d4edda' : '#fff3cd',
                border: `1px solid ${Object.values(demoChecks).every((c) => c.pass) ? '#c3e6cb' : '#ffeaa7'}`,
                borderRadius: '4px',
                textAlign: 'center',
                fontSize: '1.1rem',
                fontWeight: 'bold',
                color: Object.values(demoChecks).every((c) => c.pass) ? '#155724' : '#856404',
              }}
            >
              {Object.values(demoChecks).every((c) => c.pass)
                ? '✓ All Systems Ready'
                : '✗ Some Systems Not Ready'}
            </div>
          )}

          <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
            <a
              href="/marketplace/"
              style={{
                padding: '0.75rem 1.5rem',
                fontSize: '1rem',
                backgroundColor: '#0066cc',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
                textDecoration: 'none',
                display: 'inline-block',
              }}
            >
              Open Marketplace
            </a>
            <a
              href="/marketplace/login"
              style={{
                padding: '0.75rem 1.5rem',
                fontSize: '1rem',
                backgroundColor: '#28a745',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
                textDecoration: 'none',
                display: 'inline-block',
              }}
            >
              Login / Register
            </a>
            <button
              onClick={handleOpenMessaging}
              disabled={!listingId}
              style={{
                padding: '0.75rem 1.5rem',
                fontSize: '1rem',
                backgroundColor: listingId ? '#28a745' : '#ccc',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: listingId ? 'pointer' : 'not-allowed',
              }}
            >
              {listingError ? `Open Messaging (${listingError})` : listingId ? 'Open Messaging' : 'Open Messaging (no listing)'}
            </button>
          </div>
          {listingError && !listingId && (
            <div style={{ marginTop: '0.75rem', fontSize: '0.875rem', color: '#856404' }}>
              No published listing found. <a href="/marketplace/" style={{ color: '#0066cc' }}>Open Marketplace</a> to create one.
            </div>
          )}
        </div>

        <h1>Quick Links</h1>

        <div data-test="prototype-launcher">
          <div style={{ marginBottom: '1rem', padding: '0.5rem', border: '1px solid #ccc', borderRadius: '4px' }}>
            <div style={{ marginBottom: '0.5rem', fontWeight: 'bold' }}>Quick Links</div>
            <div style={{ fontSize: '0.875rem' }}>
              <div style={{ marginBottom: '0.25rem' }}>
                <a href="/api/v1/worlds" target="_blank" rel="noreferrer">/api/v1/worlds</a>
              </div>
              <div style={{ marginBottom: '0.25rem' }}>
                <a href="/api/v1/world/status" target="_blank" rel="noreferrer">/api/v1/world/status</a>
              </div>
              <div style={{ marginBottom: '0.25rem' }}>
                <a href="/api/marketplace/api/world/status" target="_blank" rel="noreferrer">/api/marketplace/api/world/status</a>
              </div>
              <div style={{ marginBottom: '0.25rem' }}>
                <a href="/api/messaging/api/world/status" target="_blank" rel="noreferrer">/api/messaging/api/world/status</a>
              </div>
            </div>
          </div>
        </div>

        <h1>World Directory</h1>

        {worldsError ? (
          <div className="card error">
            <div className="title">Worlds API unreachable</div>
            <pre>{String(worldsError?.message ?? worldsError)}</pre>
          </div>
        ) : (
          <div className="card">
            <div className="title">Worlds</div>
            {worldsLoading ? (
              <div>Loading worlds...</div>
            ) : (
              <div>
                {worlds.map((world) => (
                  <div key={world.world_key} style={{ marginBottom: '1rem', padding: '0.5rem', border: '1px solid #ccc', borderRadius: '4px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <strong>{world.world_key}</strong>
                        <span style={{ marginLeft: '0.5rem', padding: '0.25rem 0.5rem', borderRadius: '4px', fontSize: '0.875rem', backgroundColor: world.availability === 'ONLINE' ? '#d4edda' : world.availability === 'DISABLED' ? '#f8d7da' : '#fff3cd', color: world.availability === 'ONLINE' ? '#155724' : world.availability === 'DISABLED' ? '#721c24' : '#856404' }}>
                          {world.availability}
                        </span>
                      </div>
                      <div style={{ fontSize: '0.875rem', color: '#666' }}>
                        {world.phase} • v{world.version}
                      </div>
                    </div>
                    {world.world_key === 'marketplace' && (
                      <div style={{ marginTop: '0.5rem', fontSize: '0.875rem' }}>
                        <a href="/api/marketplace/api/world/status" target="_blank" rel="noreferrer">Direct status</a>
                      </div>
                    )}
                    {world.world_key === 'messaging' && (
                      <div style={{ marginTop: '0.5rem', fontSize: '0.875rem' }}>
                        <a href="/api/messaging/api/world/status" target="_blank" rel="noreferrer">Direct status</a>
                      </div>
                    )}
                  </div>
                ))}
                <div style={{ marginTop: '1rem', fontSize: '0.875rem' }}>
                  <a href="/api/v1/worlds" target="_blank" rel="noreferrer">H-OS API worlds endpoint</a>
                </div>
              </div>
            )}
          </div>
        )}

        <p className="hint">
          This UI is intentionally minimal. It proves that the web container builds and that nginx proxies <code>/api/*</code> to the API.
        </p>
      </main>
    </div>
  );
}