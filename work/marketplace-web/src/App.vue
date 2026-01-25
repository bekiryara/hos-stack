<template>
  <div id="app">
    <header>
      <h1>Marketplace</h1>
      <nav>
        <router-link to="/">Categories</router-link>
        <router-link to="/listing/create">Create Listing</router-link>
        <router-link to="/reservation/create">Create Reservation</router-link>
        <router-link to="/rental/create">Create Rental</router-link>
        <template v-if="isAuthenticated">
          <span class="user-identity">{{ userIdentity }}</span>
          <router-link to="/account">Hesabım</router-link>
          <button @click="handleLogout" class="logout-btn">Çıkış</button>
        </template>
        <template v-else>
          <router-link to="/auth">Giriş / Kayıt</router-link>
        </template>
      </nav>
    </header>
    <main>
      <router-view />
    </main>
  </div>
</template>

<script>
import { getToken, getUserId, decodeJwtPayload, clearSession } from './lib/demoSession.js';

export default {
  name: 'App',
  computed: {
    isAuthenticated() {
      return getToken() !== null;
    },
    userIdentity() {
      const token = getToken();
      if (!token) return '(unknown)';
      
      const payload = decodeJwtPayload(token);
      if (!payload) return '(unknown)';
      
      // Try email or preferred_username first
      if (payload.email) return payload.email;
      if (payload.preferred_username) return payload.preferred_username;
      
      // Fallback to userId
      const userId = getUserId();
      if (userId) return userId.substring(0, 8) + '...';
      
      return '(unknown)';
    },
  },
  methods: {
    handleLogout() {
      clearSession();
      this.$router.push('/auth');
    },
  },
};
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: system-ui, -apple-system, sans-serif;
  line-height: 1.6;
  color: #333;
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
  color: #0066cc;
  text-decoration: none;
  margin-left: 1rem;
}

nav a:hover {
  text-decoration: underline;
}

.user-identity {
  margin-left: 1rem;
  color: #666;
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
  max-width: 1200px;
  width: 100%;
  margin: 0 auto;
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

