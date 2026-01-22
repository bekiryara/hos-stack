export async function getHealth(): Promise<any> {
  const resp = await fetch('/api/v1/health', {
    headers: { Accept: 'application/json' },
    cache: 'no-store',
  });

  const text = await resp.text();
  let json: any = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }

  if (!resp.ok) {
    const err: any = new Error('Health request failed: ' + resp.status);
    err.status = resp.status;
    err.body = json;
    throw err;
  }

  return json;
}

export async function getWorlds(): Promise<any[]> {
  const resp = await fetch('/api/v1/worlds', {
    headers: { Accept: 'application/json' },
    cache: 'no-store',
  });

  const text = await resp.text();
  let json: any = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }

  if (!resp.ok) {
    const err: any = new Error('Worlds request failed: ' + resp.status);
    err.status = resp.status;
    err.body = json;
    throw err;
  }

  if (!Array.isArray(json)) {
    throw new Error('Expected array response from /api/v1/worlds');
  }

  return json;
}