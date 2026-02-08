<template>
  <div class="login-page">
    <div class="login-container">
      <h2>Giriş</h2>
      
      <form @submit.prevent="handleLogin" class="login-form">
        <div class="form-group">
          <label>
            Email <span class="required">*</span>
            <input
              v-model="formData.email"
              type="email"
              required
              placeholder="ornek@email.com"
              class="form-input"
              :class="{ 'error': errors.email }"
              @blur="validateEmail"
            />
          </label>
          <span v-if="errors.email" class="error-text">{{ errors.email }}</span>
        </div>
        
        <div class="form-group">
          <label>
            Şifre <span class="required">*</span>
            <input
              v-model="formData.password"
              type="password"
              required
              placeholder="••••••••"
              class="form-input"
              :class="{ 'error': errors.password }"
              @blur="validatePassword"
            />
          </label>
          <span v-if="errors.password" class="error-text">{{ errors.password }}</span>
        </div>
        
        <div v-if="error" class="error-box">
          <strong>Hata ({{ error.status || 'N/A' }}):</strong> {{ error.message || 'Giriş başarısız' }}
        </div>
        
        <button type="submit" :disabled="loading" class="submit-button">
          {{ loading ? 'Giriş yapılıyor...' : 'Giriş Yap' }}
        </button>
      </form>

      <!-- Divider: alternative sign-in methods -->
      <div v-if="googleOAuthEnabled" class="divider divider-after-form">
        <span>veya</span>
      </div>

      <!-- Google OAuth (customer-first UX; tenant slug hidden under advanced) -->
      <div v-if="googleOAuthEnabled" class="oauth-section">
        <button
          type="button"
          class="google-button"
          :disabled="googleLoading"
          @click="handleGoogleLogin"
        >
          <svg class="google-icon" viewBox="0 0 24 24" width="18" height="18">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
          {{ googleLoading ? 'Yönlendiriliyor...' : 'Google ile Giriş Yap' }}
        </button>

        <div class="oauth-hints">
          <div class="hint-text">
            Google ile girişte ilk seferde otomatik olarak <strong>müşteri</strong> hesabın oluşturulur.
          </div>
          <div v-if="tenantSlug" class="firm-indicator">
            Firma girişi aktif: <code>{{ tenantSlug }}</code>
          </div>
        </div>

        <details class="advanced-tenant" :open="showTenantOptions">
          <summary class="advanced-summary" @click.prevent="toggleTenantOptions">
            Firma (Tenant) ile giriş (opsiyonel)
          </summary>
          <div class="advanced-body">
            <div class="form-group compact">
              <label>
                Firma Slug <span class="hint-inline">(opsiyonel)</span>
                <input
                  v-model="tenantSlug"
                  type="text"
                  placeholder="tenant-slug"
                  class="form-input"
                  :class="{ 'error': errors.tenantSlug }"
                  @blur="validateTenantSlug"
                />
              </label>
              <span v-if="errors.tenantSlug" class="error-text">{{ errors.tenantSlug }}</span>
              <span class="hint-text">
                Boş bırakırsan “müşteri” olarak giriş olur. Slug girersen Google girişi o firmaya bağlanır.
              </span>
            </div>
            <button type="button" class="clear-tenant" @click="clearTenantSlug" :disabled="googleLoading">
              Firma slug’ını temizle
            </button>
          </div>
        </details>
      </div>
      
      <!-- WP-67: Show expired session message if redirected -->
      <div v-if="$route.query.reason === 'expired'" class="info-box">
        <strong>Oturum süresi doldu.</strong> Lütfen tekrar giriş yapın.
      </div>
      
      <div class="auth-links">
        <p>Hesabınız yok mu? <router-link to="/register">Kayıt Ol</router-link></p>
      </div>
    </div>
  </div>
</template>

<script>
import { login, hosApiRequest } from '../api/client.js';
import { getTenantSlug, setTenantSlug } from '../lib/session.js';
import { notifyError } from '../lib/toast/notify.js';

export default {
  name: 'LoginPage',
  data() {
    return {
      formData: {
        email: '',
        password: '',
      },
      errors: {},
      loading: false,
      error: null,
      // WP-NEXT: Google OAuth state
      tenantSlug: '',
      tenantSlugFromContext: false, // true if slug came from URL or localStorage (prefill only)
      showTenantOptions: false,
      googleOAuthEnabled: false,
      googleLoading: false,
    };
  },
  async mounted() {
    // WP-NEXT: Initialize tenantSlug from query > localStorage > empty
    const fromQuery = this.$route.query.tenantSlug;
    const fromStorage = getTenantSlug();
    
    if (fromQuery) {
      this.tenantSlug = fromQuery;
      this.tenantSlugFromContext = true;
    } else if (fromStorage) {
      this.tenantSlug = fromStorage;
      this.tenantSlugFromContext = true;
    } else {
      this.tenantSlug = '';
      this.tenantSlugFromContext = false;
    }
    // If a slug is already known, keep advanced section open to avoid hidden behavior.
    this.showTenantOptions = Boolean(this.tenantSlug);
    
    // WP-NEXT: Fetch feature flags to check if Google OAuth is enabled
    await this.loadFeatureFlags();
    // Toast when redirected due to expired/missing auth
    if (this.$route.query.reason === 'expired') {
      notifyError('Auth required');
    }
  },
  methods: {
    async loadFeatureFlags() {
      try {
        // Use hosApiRequest for /v1/meta/features (same-origin proxy)
        const features = await hosApiRequest('/v1/meta/features', {}, true);
        this.googleOAuthEnabled = features?.googleOAuthConfigured === true;
      } catch (err) {
        // If feature flags fail to load, disable Google OAuth gracefully
        console.warn('Failed to load feature flags:', err);
        this.googleOAuthEnabled = false;
      }
    },
    validateTenantSlug() {
      const slug = this.tenantSlug.trim();
      if (!slug) {
        // Public customer Google login: tenant slug is optional.
        delete this.errors.tenantSlug;
        return true;
      }
      // Basic slug validation: lowercase, alphanumeric, hyphens
      if (!/^[a-z0-9-]+$/.test(slug)) {
        this.errors.tenantSlug = 'Geçerli bir slug giriniz (küçük harf, rakam, tire)';
        return false;
      }
      delete this.errors.tenantSlug;
      return true;
    },
    toggleTenantOptions() {
      this.showTenantOptions = !this.showTenantOptions;
    },
    clearTenantSlug() {
      this.tenantSlug = '';
      delete this.errors.tenantSlug;
      setTenantSlug('');
      this.showTenantOptions = false;
    },
    handleGoogleLogin() {
      // Validate tenantSlug before redirect
      if (!this.validateTenantSlug()) {
        return;
      }
      
      this.googleLoading = true;
      
      // Save tenantSlug to localStorage for future use
      const slug = this.tenantSlug.trim();
      setTenantSlug(slug || '');
      
      // Redirect to HOS Google OAuth start endpoint (via nginx proxy)
      // /api proxies to HOS API (localhost:3000)
      const redirectUrl = slug
        ? `/api/v1/auth/google/start?tenantSlug=${encodeURIComponent(slug)}`
        : `/api/v1/auth/google/start`;
      window.location.href = redirectUrl;
    },
    validateEmail() {
      const email = this.formData.email.trim();
      if (!email) {
        this.errors.email = 'Email gereklidir';
        return false;
      }
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(email)) {
        this.errors.email = 'Geçerli bir email adresi giriniz';
        return false;
      }
      delete this.errors.email;
      return true;
    },
    validatePassword() {
      const password = this.formData.password;
      if (!password) {
        this.errors.password = 'Şifre gereklidir';
        return false;
      }
      if (password.length < 6) {
        this.errors.password = 'Şifre en az 6 karakter olmalıdır';
        return false;
      }
      delete this.errors.password;
      return true;
    },
    async handleLogin() {
      // Clear previous errors
      this.error = null;
      this.errors = {};
      
      // Validate
      const emailValid = this.validateEmail();
      const passwordValid = this.validatePassword();
      
      if (!emailValid || !passwordValid) {
        return;
      }
      
      this.loading = true;
      
      try {
        await login(this.formData.email.trim(), this.formData.password);
        
        // Redirect to account page
        this.$router.push('/account');
      } catch (err) {
        this.error = {
          status: err.status || 0,
          message: err.message || 'Giriş başarısız',
        };
        notifyError('Login failed');
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<style scoped>
.login-page {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 60vh;
  padding: 2rem;
}

.login-container {
  width: 100%;
  max-width: 400px;
  background: #fff;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  padding: 2rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.login-container h2 {
  margin-bottom: 1.5rem;
  text-align: center;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
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
  padding: 0.75rem;
  border: 1px solid #ced4da;
  border-radius: 4px;
  font-size: 1rem;
}

.form-input.error {
  border-color: #dc3545;
}

.error-text {
  color: #dc3545;
  font-size: 0.875rem;
  margin-top: 0.25rem;
}

.error-box {
  background: #f8d7da;
  color: #721c24;
  padding: 0.75rem;
  border-radius: 4px;
  border: 1px solid #f5c6cb;
}

.info-box {
  background: #d1ecf1;
  color: #0c5460;
  padding: 0.75rem;
  border-radius: 4px;
  border: 1px solid #bee5eb;
  margin-bottom: 1rem;
}

.submit-button {
  padding: 0.75rem 1.5rem;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
  font-weight: 500;
}

.submit-button:hover:not(:disabled) {
  background: #0056b3;
}

.submit-button:disabled {
  background: #6c757d;
  cursor: not-allowed;
}

.auth-links {
  margin-top: 1.5rem;
  text-align: center;
}

.auth-links a {
  color: #007bff;
  text-decoration: none;
}

.auth-links a:hover {
  text-decoration: underline;
}

/* WP-NEXT: Google OAuth styles */
.oauth-section {
  margin-top: 1rem;
  margin-bottom: 1.25rem;
}

.google-button {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.75rem 1rem;
  background: #fff;
  color: #3c4043;
  border: 1px solid #dadce0;
  border-radius: 4px;
  font-size: 0.95rem;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s, box-shadow 0.2s;
}

.google-button:hover:not(:disabled) {
  background: #f8f9fa;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.google-button:disabled {
  background: #f1f3f4;
  color: #80868b;
  cursor: not-allowed;
}

.google-icon {
  flex-shrink: 0;
}

.divider {
  display: flex;
  align-items: center;
  margin: 1.5rem 0;
}

.divider::before,
.divider::after {
  content: '';
  flex: 1;
  border-bottom: 1px solid #dee2e6;
}

.divider span {
  padding: 0 1rem;
  color: #6c757d;
  font-size: 0.875rem;
}

.hint-text {
  display: block;
  font-size: 0.75rem;
  color: #6c757d;
  margin-top: 0.25rem;
}

.hint-inline {
  font-size: 0.8rem;
  color: #6c757d;
  font-weight: 400;
}

.divider-after-form {
  margin-top: 1.25rem;
  margin-bottom: 1rem;
}

.oauth-hints {
  margin-top: 0.5rem;
}

.firm-indicator {
  margin-top: 0.25rem;
  font-size: 0.8rem;
  color: #444;
}

.firm-indicator code {
  background: #f3f4f6;
  padding: 0.1rem 0.35rem;
  border-radius: 4px;
  border: 1px solid #e5e7eb;
}

.advanced-tenant {
  margin-top: 0.75rem;
  border: 1px solid #e9ecef;
  border-radius: 6px;
  padding: 0.75rem;
  background: #fafafa;
}

.advanced-summary {
  cursor: pointer;
  font-weight: 600;
  color: #333;
  user-select: none;
  list-style: none;
}

.advanced-summary::-webkit-details-marker {
  display: none;
}

.advanced-summary::before {
  content: '▸';
  display: inline-block;
  margin-right: 0.5rem;
  color: #6c757d;
  transform: rotate(0deg);
  transition: transform 0.15s ease-in-out;
}

.advanced-tenant[open] .advanced-summary::before {
  transform: rotate(90deg);
}

.advanced-body {
  margin-top: 0.75rem;
}

.form-group.compact {
  gap: 0.25rem;
}

.clear-tenant {
  margin-top: 0.5rem;
  padding: 0.4rem 0.65rem;
  font-size: 0.85rem;
  border: 1px solid #ced4da;
  border-radius: 4px;
  background: #fff;
  color: #444;
  cursor: pointer;
}

.clear-tenant:hover:not(:disabled) {
  background: #f1f3f5;
}

.clear-tenant:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>

