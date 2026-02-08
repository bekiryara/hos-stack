<template>
  <div class="oauth-complete-page">
    <div class="card">
      <h2>Giriş tamamlanıyor…</h2>

      <p v-if="status === 'working'">
        Google ile giriş tamamlandı. Hesabınıza yönlendiriliyorsunuz…
      </p>

      <div v-else class="error">
        <p>Google ile giriş tamamlanamadı.</p>
        <p class="muted">
          <router-link to="/login">Giriş sayfasına dön</router-link>
        </p>
        <pre v-if="error" class="error-box">{{ error }}</pre>
      </div>
    </div>
  </div>
</template>

<script>
import { hosApiRequest } from '../api/request.js';
import { saveSession, setToken } from '../lib/session.js';

function readFragmentParams() {
  try {
    const raw = String(window.location.hash || '').replace(/^#/, '');
    return new URLSearchParams(raw);
  } catch {
    return new URLSearchParams();
  }
}

function clearUrlFragment() {
  try {
    const clean = `${window.location.pathname}${window.location.search}`;
    window.history.replaceState(null, document.title, clean);
  } catch {
    // ignore
  }
}

export default {
  name: 'OAuthCompletePage',
  data() {
    return {
      status: 'working', // working | error
      error: null,
    };
  },
  async mounted() {
    const params = readFragmentParams();
    const token = params.get('token');

    if (!token) {
      this.status = 'error';
      const reason = this.$route?.query?.reason || 'missing_token';
      this.error = `reason=${String(reason)}`;
      return;
    }

    // Store token immediately so auth-required routing works.
    setToken(token);
    clearUrlFragment();

    // Hydrate user for better UX (optional; token is enough to be "logged in").
    try {
      const me = await hosApiRequest('/v1/me', {}, false);
      const user = {
        email: me?.email || null,
        id: me?.user_id || me?.id || null,
      };
      saveSession(token, user);
    } catch {
      // Keep token-only session
      saveSession(token, null);
    }

    this.$router.replace({ path: '/account' }).catch(() => {});
  },
};
</script>

<style scoped>
.oauth-complete-page {
  min-height: calc(100vh - 60px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.card {
  width: min(640px, 100%);
  background: #111827;
  color: #e5e7eb;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 14px;
  padding: 20px 18px;
  box-shadow: 0 12px 30px rgba(0, 0, 0, 0.35);
}

.error {
  margin-top: 12px;
}

.muted {
  opacity: 0.85;
}

.error-box {
  margin-top: 12px;
  padding: 12px;
  background: rgba(239, 68, 68, 0.08);
  border: 1px solid rgba(239, 68, 68, 0.25);
  border-radius: 10px;
  overflow: auto;
}
</style>

