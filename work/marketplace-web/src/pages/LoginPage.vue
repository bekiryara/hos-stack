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
      
      <div class="auth-links">
        <p>Hesabınız yok mu? <router-link to="/register">Kayıt Ol</router-link></p>
      </div>
    </div>
  </div>
</template>

<script>
import { login } from '../lib/api.js';
import { saveSession } from '../lib/session.js';

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
    };
  },
  methods: {
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
        const result = await login(this.formData.email.trim(), this.formData.password);
        
        // Save session
        saveSession({
          token: result.token,
          user: result.user || { email: this.formData.email.trim() },
        });
        
        // Redirect to account page
        this.$router.push('/account');
      } catch (err) {
        this.error = {
          status: err.status || 0,
          message: err.message || 'Giriş başarısız',
        };
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
</style>

