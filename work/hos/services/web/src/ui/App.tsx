import React, { useEffect, useState } from 'react';
import { getHealth, getWorlds } from '../lib/api';

export function App() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<any>(null);
  const [worldsLoading, setWorldsLoading] = useState(true);
  const [worlds, setWorlds] = useState<any[]>([]);
  const [worldsError, setWorldsError] = useState<any>(null);

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
  }, []);

  return (
    <div className="page">
      <header className="top">
        <div className="brand">H-OS Admin</div>
        <div className="actions">
          <button onClick={load} disabled={loading}>
            {loading ? 'Loading…' : 'Refresh'}
          </button>
          <button onClick={loadWorlds} disabled={worldsLoading} style={{ marginLeft: '0.5rem' }}>
            {worldsLoading ? 'Loading…' : 'Refresh Worlds'}
          </button>
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

        <h1>Prototype Launcher</h1>

        <div data-test="prototype-launcher">
          <div style={{ marginBottom: '1rem', padding: '1rem', border: '1px solid #ccc', borderRadius: '4px', backgroundColor: '#f9f9f9' }}>
            <div style={{ marginBottom: '1rem', fontWeight: 'bold', fontSize: '1.1rem' }}>Demo Login</div>
            <button
              onClick={async () => {
                try {
                  const response = await fetch('/api/v1/auth/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                      tenantSlug: 'tenant-a',
                      email: 'testuser@example.com',
                      password: 'Passw0rd!',
                    }),
                  });
                  if (!response.ok) {
                    throw new Error('Login failed');
                  }
                  const data = await response.json();
                  if (data.token) {
                    localStorage.setItem('demo_auth_token', data.token);
                    window.location.href = 'http://localhost:8080/demo';
                  }
                } catch (err) {
                  alert('Demo login failed: ' + (err as Error).message);
                }
              }}
              style={{
                padding: '0.75rem 1.5rem',
                fontSize: '1rem',
                backgroundColor: '#0066cc',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
              }}
            >
              Enter Demo
            </button>
            <div style={{ marginTop: '0.5rem', fontSize: '0.875rem', color: '#666' }}>
              Authenticates as demo user and opens marketplace
            </div>
          </div>
          <div style={{ marginBottom: '1rem', padding: '0.5rem', border: '1px solid #ccc', borderRadius: '4px' }}>
            <div style={{ marginBottom: '0.5rem', fontWeight: 'bold' }}>Quick Links</div>
            <div style={{ fontSize: '0.875rem' }}>
              <div style={{ marginBottom: '0.25rem' }}>
                <a href="http://localhost:3000/v1/worlds" target="_blank" rel="noreferrer">http://localhost:3000/v1/worlds</a>
              </div>
              <div style={{ marginBottom: '0.25rem' }}>
                <a href="http://localhost:3000/v1/world/status" target="_blank" rel="noreferrer">http://localhost:3000/v1/world/status</a>
              </div>
              <div style={{ marginBottom: '0.25rem' }}>
                <a href="http://localhost:8080/api/world/status" target="_blank" rel="noreferrer">http://localhost:8080/api/world/status</a>
              </div>
              <div style={{ marginBottom: '0.25rem' }}>
                <a href="http://localhost:8090/api/world/status" target="_blank" rel="noreferrer">http://localhost:8090/api/world/status</a>
                {process.env.MESSAGING_PUBLIC_URL && (
                  <span style={{ marginLeft: '0.5rem', fontSize: '0.75rem', color: '#666' }}>
                    (env override: {process.env.MESSAGING_PUBLIC_URL})
                  </span>
                )}
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
                        <a href="http://localhost:8080/api/world/status" target="_blank" rel="noreferrer">Direct status</a>
                      </div>
                    )}
                    {world.world_key === 'messaging' && (
                      <div style={{ marginTop: '0.5rem', fontSize: '0.875rem' }}>
                        <a href="http://localhost:8090/api/world/status" target="_blank" rel="noreferrer">Direct status</a>
                      </div>
                    )}
                  </div>
                ))}
                <div style={{ marginTop: '1rem', fontSize: '0.875rem' }}>
                  <a href="http://localhost:3000/v1/worlds" target="_blank" rel="noreferrer">H-OS API worlds endpoint</a>
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