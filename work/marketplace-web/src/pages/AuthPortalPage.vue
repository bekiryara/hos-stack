<template>
  <div class="auth-portal-page">
    <h2>Auth Portal</h2>
    
    <!-- Success Banner -->
    <div v-if="successMessage" class="success-banner">
      <strong>Başarılı!</strong> {{ successMessage }}
      <div class="success-actions">
        <router-link to="/account" class="action-button">Hesabıma Git</router-link>
        <router-link to="/" class="action-button">Ana Sayfa</router-link>
      </div>
    </div>
    
    <!-- Session Panel -->
    <div v-if="isAuthenticated" class="session-panel">
      <h3>Session</h3>
      <div class="session-info">
        <div><strong>Status:</strong> Logged in</div>
        <div v-if="tenantSlug"><strong>Tenant Slug:</strong> {{ tenantSlug }}</div>
        <div v-if="tenantId"><strong>Tenant ID:</strong> {{ tenantId }}</div>
        <div v-if="userId"><strong>User ID:</strong> {{ userId }}</div>
        <div v-if="role"><strong>Role:</strong> {{ role }}</div>
      </div>
      <div class="session-actions">
        <button @click="handleLogout" class="logout-button">Logout (Clear Session)</button>
        <router-link to="/listing/create" class="action-link">Create Listing</router-link>
        <router-link to="/search" class="action-link">Listings</router-link>
        <router-link to="/account" class="action-link">Account</router-link>
      </div>
    </div>
    
    <!-- Auth Forms -->
    <div v-else class="auth-forms">
      <!-- New Tenant Flow -->
      <div class="auth-section">
        <h3>Create Tenant + Register Owner</h3>
        <form @submit.prevent="handleCreateTenantAndRegister" class="auth-form">
          <div class="form-group">
            <label>
              Tenant Slug <span class="required">*</span>
              <input v-model="newTenantForm.slug" type="text" required placeholder="my-tenant" class="form-input" />
            </label>
          </div>
          <div class="form-group">
            <label>
              Tenant Name <span class="required">*</span>
              <input v-model="newTenantForm.name" type="text" required placeholder="My Tenant" class="form-input" />
            </label>
          </div>
          <div class="form-group">
            <label>
              Email <span class="required">*</span>
              <input v-model="newTenantForm.email" type="email" required placeholder="owner@example.com" class="form-input" />
            </label>
          </div>
          <div class="form-group">
            <label>
              Password <span class="required">*</span>
              <input v-model="newTenantForm.password" type="password" required placeholder="Password" class="form-input" />
            </label>
          </div>
          <div v-if="newTenantError" class="error">
            <strong>Hata ({{ newTenantErrorStatus || 'N/A' }}):</strong> {{ newTenantError }}
          </div>
          <button type="submit" :disabled="newTenantLoading" class="submit-button">
            {{ newTenantLoading ? 'Creating...' : 'Create Tenant + Register' }}
          </button>
        </form>
      </div>
      
      <!-- Login Flow -->
      <div class="auth-section">
        <h3>Login</h3>
        <form @submit.prevent="handleLogin" class="auth-form">
          <div class="form-group">
            <label>
              Tenant Slug <span class="required">*</span>
              <input v-model="loginForm.tenantSlug" type="text" required placeholder="my-tenant" class="form-input" />
            </label>
          </div>
          <div class="form-group">
            <label>
              Email <span class="required">*</span>
              <input v-model="loginForm.email" type="email" required placeholder="user@example.com" class="form-input" />
            </label>
          </div>
          <div class="form-group">
            <label>
              Password <span class="required">*</span>
              <input v-model="loginForm.password" type="password" required placeholder="Password" class="form-input" />
            </label>
          </div>
          <div v-if="loginError" class="error">
            <strong>Hata ({{ loginErrorStatus || 'N/A' }}):</strong> {{ loginError }}
          </div>
          <button type="submit" :disabled="loginLoading" class="submit-button">
            {{ loginLoading ? 'Logging in...' : 'Login' }}
          </button>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client';
import {
  getToken,
  setToken,
  clearSession,
  getTenantSlug,
  setTenantSlug,
  getTenantId,
  getUserId,
  setUserId,
  getRole,
  decodeJwtPayload,
  setActiveTenantId,
} from '../lib/demoSession.js';

export default {
  name: 'AuthPortalPage',
  data() {
    return {
      newTenantForm: {
        slug: '',
        name: '',
        email: '',
        password: '',
      },
      loginForm: {
        tenantSlug: '',
        email: '',
        password: '',
      },
      newTenantLoading: false,
      newTenantError: null,
      newTenantErrorStatus: null,
      loginLoading: false,
      loginError: null,
      loginErrorStatus: null,
      successMessage: null,
    };
  },
  computed: {
    isAuthenticated() {
      return getToken() !== null;
    },
    tenantSlug() {
      return getTenantSlug();
    },
    tenantId() {
      return getTenantId();
    },
    userId() {
      return getUserId();
    },
    role() {
      return getRole();
    },
  },
  mounted() {
    // Load saved tenant slug if available
    const savedSlug = getTenantSlug();
    if (savedSlug) {
      this.loginForm.tenantSlug = savedSlug;
    }
  },
  methods: {
    async handleCreateTenantAndRegister() {
      this.newTenantLoading = true;
      this.newTenantError = null;
      
      try {
        // Step 1: Create tenant
        const tenantResult = await api.hosCreateTenant({
          slug: this.newTenantForm.slug,
          name: this.newTenantForm.name,
        });
        
        // Step 2: Register owner
        const registerResult = await api.hosRegisterOwner({
          tenantSlug: this.newTenantForm.slug,
          email: this.newTenantForm.email,
          password: this.newTenantForm.password,
        });
        
        // Save token and session data
        if (registerResult.token) {
          setToken(registerResult.token);
          setTenantSlug(this.newTenantForm.slug);
          
          // Extract tenantId and userId from token payload
          const payload = decodeJwtPayload(registerResult.token);
          if (payload?.tenantId || payload?.tenant_id) {
            const tid = payload.tenantId || payload.tenant_id;
            setActiveTenantId(tid);
          }
          // Store userId if present in payload
          if (payload?.sub) {
            setUserId(payload.sub);
          }
          
          // Clear form
          this.newTenantForm = { slug: '', name: '', email: '', password: '' };
          
          // Show success
          this.successMessage = 'Tenant oluşturuldu ve owner kaydedildi.';
          this.newTenantError = null;
          this.newTenantErrorStatus = null;
        } else {
          throw new Error('No token received from registration');
        }
      } catch (error) {
        this.newTenantError = error.message || 'Failed to create tenant and register owner';
        this.newTenantErrorStatus = error.status || null;
        this.successMessage = null;
        console.error('Create tenant error:', error);
      } finally {
        this.newTenantLoading = false;
      }
    },
    
    async handleLogin() {
      this.loginLoading = true;
      this.loginError = null;
      
      try {
        const result = await api.hosLogin({
          tenantSlug: this.loginForm.tenantSlug,
          email: this.loginForm.email,
          password: this.loginForm.password,
        });
        
        // Save token and session data
        if (result.token) {
          setToken(result.token);
          setTenantSlug(this.loginForm.tenantSlug);
          
          // Extract tenantId and userId from token payload
          const payload = decodeJwtPayload(result.token);
          if (payload?.tenantId || payload?.tenant_id) {
            const tid = payload.tenantId || payload.tenant_id;
            setActiveTenantId(tid);
          }
          // Store userId if present in payload
          if (payload?.sub) {
            setUserId(payload.sub);
          }
          
          // Clear form
          this.loginForm = { tenantSlug: this.loginForm.tenantSlug, email: '', password: '' };
          
          // Show success
          this.successMessage = 'Giriş başarılı.';
          this.loginError = null;
          this.loginErrorStatus = null;
        } else {
          throw new Error('No token received from login');
        }
      } catch (error) {
        this.loginError = error.message || 'Failed to login';
        this.loginErrorStatus = error.status || null;
        this.successMessage = null;
        console.error('Login error:', error);
      } finally {
        this.loginLoading = false;
      }
    },
    
    handleLogout() {
      clearSession();
      this.successMessage = null;
      // Redirect to auth portal
      this.$router.push('/auth');
    },
  },
};
</script>

<style scoped>
.auth-portal-page {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
}

.session-panel {
  background: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  padding: 1.5rem;
  margin-bottom: 2rem;
}

.session-info {
  margin-bottom: 1rem;
}

.session-info div {
  margin-bottom: 0.5rem;
}

.session-actions {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.logout-button {
  background: #dc3545;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  cursor: pointer;
}

.logout-button:hover {
  background: #c82333;
}

.auth-forms {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
}

.auth-section {
  background: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  padding: 1.5rem;
}

.auth-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-group {
  display: flex;
  flex-direction: column;
}

.form-group label {
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.required {
  color: #dc3545;
}

.form-input {
  padding: 0.5rem;
  border: 1px solid #ced4da;
  border-radius: 4px;
  font-size: 1rem;
}

.submit-button {
  background: #007bff;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
}

.submit-button:hover:not(:disabled) {
  background: #0056b3;
}

.submit-button:disabled {
  background: #6c757d;
  cursor: not-allowed;
}

.error {
  background: #f8d7da;
  color: #721c24;
  padding: 0.75rem;
  border-radius: 4px;
  border: 1px solid #f5c6cb;
}

.action-link {
  color: #007bff;
  text-decoration: none;
  padding: 0.5rem 1rem;
  border: 1px solid #007bff;
  border-radius: 4px;
  display: inline-block;
}

.action-link:hover {
  background: #007bff;
  color: white;
}

.success-banner {
  background: #d4edda;
  color: #155724;
  padding: 1rem;
  border-radius: 4px;
  border: 1px solid #c3e6cb;
  margin-bottom: 2rem;
}

.success-actions {
  margin-top: 1rem;
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.action-button {
  display: inline-block;
  padding: 0.5rem 1rem;
  background: #28a745;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  font-size: 0.9rem;
}

.action-button:hover {
  background: #218838;
}

@media (max-width: 768px) {
  .auth-forms {
    grid-template-columns: 1fr;
  }
}
</style>

