<template>
  <div id="app">
    <header>
      <h1>Marketplace</h1>
      <nav>
        <router-link to="/">Keşfet</router-link>
        <router-link to="/search">Ara</router-link>
        <template v-if="isAuthenticated">
          <router-link to="/account">Hesabım</router-link>
          <span class="user-identity">{{ userIdentity }}</span>
          <button @click="handleLogout" class="logout-btn">Çıkış</button>
        </template>
        <template v-else>
          <router-link to="/login">Giriş</router-link>
          <router-link to="/register">Kayıt Ol</router-link>
        </template>
      </nav>
    </header>
    <main>
      <router-view />
    </main>
    <ToastHost />
  </div>
</template>

<script>
import { api } from './api/client.js';
import { isLoggedIn, getUser, clearSession, getActiveTenantId } from './lib/session.js';
import ToastHost from './components/ToastHost.vue';

export default {
  name: 'App',
  components: { ToastHost },
  data() {
    return {
      // Forces re-computation of computed properties when session changes.
      sessionVersion: 0,
    };
  },
  computed: {
    isAuthenticated() {
      void this.sessionVersion;
      return isLoggedIn();
    },
    userIdentity() {
      void this.sessionVersion;
      const user = getUser();
      if (user && user.email) {
        return user.email;
      }
      return '(unknown)';
    },
    hasActiveTenant() {
      void this.sessionVersion;
      return Boolean(getActiveTenantId());
    },
  },
  mounted() {
    window.addEventListener('session-changed', this.onSessionChanged);
  },
  beforeUnmount() {
    window.removeEventListener('session-changed', this.onSessionChanged);
  },
  methods: {
    onSessionChanged() {
      this.sessionVersion += 1;
    },
    async handleLogout() {
      // Best-effort: revoke server-side refresh cookie, then clear local session.
      try {
        await api.hosLogout();
      } catch {
        // ignore; local logout still proceeds
      } finally {
        clearSession();
        this.$router.push('/login');
      }
    },
  },
};
</script>

<style>
:root {
  /* Neutral, consistent palette */
  --text-strong: #1f2937; /* headings */
  --text: #374151; /* body */
  --text-muted: #6b7280;
  --text-label: #4b5563;
  --border: #e5e7eb;
  --surface: #ffffff;
  --surface-2: #f8fafc;
  --link: #2563eb;
  --btn-neutral: #111827;
  --btn-neutral-hover: #0b1220;
  --pill-bg: #f1f5f9;
  --pill-text: #334155;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: system-ui, -apple-system, sans-serif;
  line-height: 1.6;
  color: var(--text);
  background: var(--surface);
}

#app {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

header {
  background: #f5f5f5;
  padding: 1rem 2rem;
  border-bottom: 1px solid #ddd;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

header h1 {
  font-size: 1.5rem;
}

nav a {
  color: var(--link);
  text-decoration: none;
  margin-left: 1rem;
}

nav a:hover {
  text-decoration: underline;
}

.user-identity {
  margin-left: 1rem;
  color: var(--text-muted);
  font-size: 0.9rem;
}

.logout-btn {
  margin-left: 1rem;
  padding: 0.5rem 1rem;
  background: #dc3545;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.logout-btn:hover {
  background: #c82333;
}

main {
  flex: 1;
  padding: 2rem;
  width: 100%;
  margin: 0;
}

.error {
  color: #d32f2f;
  padding: 1rem;
  background: #ffebee;
  border-radius: 4px;
  margin: 1rem 0;
}

.loading {
  text-align: center;
  padding: 2rem;
  color: #666;
}
</style>

