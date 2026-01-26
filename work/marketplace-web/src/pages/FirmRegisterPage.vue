<template>
  <div class="firm-register-page">
    <h2>Firma Oluştur</h2>
    
    <!-- Not logged in -->
    <div v-if="!isAuthenticated" class="not-logged-in">
      <p>Firma oluşturmak için giriş yapmanız gerekiyor.</p>
      <router-link to="/login" class="login-link">Giriş Yap</router-link>
    </div>
    
    <!-- Logged in - Registration form -->
    <div v-else class="registration-form">
      <form @submit.prevent="handleSubmit">
        <div class="form-group">
          <label for="firm-name">Firma Adı *</label>
          <input
            id="firm-name"
            v-model="formData.firm_name"
            type="text"
            required
            placeholder="Örn: ABC Teknoloji"
            maxlength="100"
          />
          <small>Firma adı, URL'de slug olarak kullanılacaktır.</small>
        </div>
        
        <div class="form-group">
          <label for="firm-owner-name">Firma Sahibi Adı</label>
          <input
            id="firm-owner-name"
            v-model="formData.firm_owner_name"
            type="text"
            placeholder="İsteğe bağlı"
            maxlength="100"
          />
        </div>
        
        <div v-if="error" class="error-message">
          {{ error }}
        </div>
        
        <div v-if="success" class="success-message">
          {{ success }}
        </div>
        
        <div class="form-actions">
          <button type="submit" :disabled="loading || submitting" class="submit-btn">
            {{ submitting ? 'Oluşturuluyor...' : 'Firma Oluştur' }}
          </button>
          <router-link to="/account" class="cancel-link">İptal</router-link>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client.js';
import { isLoggedIn, setActiveTenantId } from '../lib/demoSession.js';

export default {
  name: 'FirmRegisterPage',
  data() {
    return {
      formData: {
        firm_name: '',
        firm_owner_name: '',
      },
      loading: false,
      submitting: false,
      error: null,
      success: null,
    };
  },
  computed: {
    isAuthenticated() {
      return isLoggedIn();
    },
  },
  async mounted() {
    // WP-68: Redirect to login if not authenticated (guard)
    if (!this.isAuthenticated) {
      this.$router.push('/login?reason=expired');
      return;
    }
    // WP-68: Ensure form is visible when authenticated
    this.loading = false;
  },
  methods: {
    generateSlug(name) {
      // WP-68: Generate slug from firm name (lowercase, dash)
      return name
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '');
    },
    async handleSubmit() {
      if (!this.formData.firm_name.trim()) {
        this.error = 'Firma adı gereklidir.';
        return;
      }
      
      this.submitting = true;
      this.error = null;
      this.success = null;
      
      try {
        const slug = this.generateSlug(this.formData.firm_name);
        const displayName = this.formData.firm_owner_name.trim() || this.formData.firm_name.trim();
        
        // WP-68: Call POST /v1/tenants/v2
        const response = await api.hosCreateTenant({
          slug,
          display_name: displayName,
        });
        
        if (response.tenant_id) {
          // WP-68: Set active tenant
          setActiveTenantId(response.tenant_id);
          
          this.success = `Firma başarıyla oluşturuldu! (${response.slug})`;
          
          // WP-68: Redirect to account page after success (not demo)
          await new Promise(resolve => setTimeout(resolve, 1500)); // Brief delay for UX
          this.$router.push('/account');
        } else {
          this.error = 'Firma oluşturulamadı. Lütfen tekrar deneyin.';
        }
      } catch (err) {
        if (err.status === 401) {
          this.error = 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
          setTimeout(() => {
            this.$router.push('/login?reason=expired');
          }, 2000);
        } else if (err.status === 409) {
          this.error = 'Bu firma adı zaten kullanılıyor. Lütfen farklı bir ad seçin.';
        } else {
          this.error = err.message || 'Firma oluşturulurken bir hata oluştu.';
        }
      } finally {
        this.submitting = false;
      }
    },
  },
};
</script>

<style scoped>
.firm-register-page {
  max-width: 600px;
  margin: 0 auto;
  padding: 2rem;
}

.firm-register-page h2 {
  margin-bottom: 2rem;
  color: #333;
}

.not-logged-in {
  text-align: center;
  padding: 3rem;
  background: #f8f9fa;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.not-logged-in p {
  margin-bottom: 1.5rem;
  color: #666;
}

.login-link {
  display: inline-block;
  padding: 0.75rem 2rem;
  background: #007bff;
  color: white;
  text-decoration: none;
  border-radius: 4px;
}

.login-link:hover {
  background: #0056b3;
}

.registration-form {
  background: #f8f9fa;
  padding: 2rem;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 600;
  color: #333;
}

.form-group input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ced4da;
  border-radius: 4px;
  font-size: 1rem;
  box-sizing: border-box;
}

.form-group input:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
}

.form-group small {
  display: block;
  margin-top: 0.25rem;
  color: #666;
  font-size: 0.875rem;
}

.error-message {
  padding: 1rem;
  background: #f8d7da;
  color: #721c24;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.success-message {
  padding: 1rem;
  background: #d4edda;
  color: #155724;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.form-actions {
  display: flex;
  gap: 1rem;
  margin-top: 2rem;
}

.submit-btn {
  flex: 1;
  padding: 0.75rem 2rem;
  background: #28a745;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
}

.submit-btn:hover:not(:disabled) {
  background: #218838;
}

.submit-btn:disabled {
  background: #6c757d;
  cursor: not-allowed;
}

.cancel-link {
  padding: 0.75rem 2rem;
  color: #666;
  text-decoration: none;
  border-radius: 4px;
  border: 1px solid #ced4da;
  display: inline-block;
}

.cancel-link:hover {
  background: #e9ecef;
}
</style>

