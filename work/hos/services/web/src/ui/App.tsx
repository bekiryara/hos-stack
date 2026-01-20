import React, { useEffect, useState } from 'react';
import { getHealth } from '../lib/api';

export function App() {
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState<any>(null);

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

  useEffect(() => {
    load();
  }, []);

  return (
    <div className="page">
      <header className="top">
        <div className="brand">H-OS Admin</div>
        <div className="actions">
          <button onClick={load} disabled={loading}>
            {loading ? 'Loading…' : 'Refresh'}
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

        <p className="hint">
          This UI is intentionally minimal. It proves that the web container builds and that nginx proxies <code>/api/*</code> to the API.
        </p>
      </main>
    </div>
  );
}