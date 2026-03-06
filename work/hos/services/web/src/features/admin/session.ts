const TOKEN_KEY = 'hos_admin_token';
const EMAIL_KEY = 'hos_admin_email';

export function getAdminToken(): string {
  try {
    return localStorage.getItem(TOKEN_KEY) || '';
  } catch {
    return '';
  }
}

export function hasAdminToken(): boolean {
  return Boolean(getAdminToken());
}

export function setAdminSession(token: string, email?: string) {
  try {
    localStorage.setItem(TOKEN_KEY, token || '');
    if (email) localStorage.setItem(EMAIL_KEY, email);
  } catch {}
}

export function clearAdminSession() {
  try {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(EMAIL_KEY);
  } catch {}
}

export function getAdminEmail(): string {
  try {
    return localStorage.getItem(EMAIL_KEY) || '';
  } catch {
    return '';
  }
}

