<template>
  <div class="firm-register-page">
    <h2>Firma Olustur</h2>

    <div v-if="!isAuthenticated" class="not-logged-in">
      <p>Firma olusturmak icin giris yapmaniz gerekiyor.</p>
      <router-link to="/login" class="login-link">Giris Yap</router-link>
    </div>

    <div v-else>
      <div v-if="loading" class="loading-message">
        <p>Hesap bilgileri kontrol ediliyor...</p>
        <p class="muted">Mevcut bir firmaniz varsa otomatik yonlendirileceksiniz.</p>
      </div>

      <div v-else>
        <div v-if="gateState === 'already_active'" class="info-message">
          <p><strong>Bu hesapta zaten aktif bir firma var.</strong></p>
          <p class="muted">Yeni firma olusturmana gerek yok. Istersen firma paneline gecebilirsin.</p>
          <div class="cta-row">
            <router-link to="/account" class="secondary-link">Hesabim</router-link>
            <button type="button" class="primary-btn" @click="goToListingCreate">Ilan Olustur</button>
          </div>
        </div>

        <div v-else-if="gateState === 'has_memberships'" class="info-message">
          <p><strong>Bu hesapta mevcut firma uyeligi var.</strong></p>
          <p class="muted">Firma secimini netlestirmek icin once Hesabim sayfasina gidebilirsin.</p>
          <div class="cta-row">
            <router-link to="/account" class="secondary-link">Hesabim (firma sec)</router-link>
            <button
              v-if="preferredTenantId"
              type="button"
              class="primary-btn"
              @click="activatePreferredAndContinue"
            >
              Aktif yap ve devam et
            </button>
          </div>
          <div v-if="membershipsPreview.length > 0" class="memberships-preview">
            <div class="muted">Bulunan firmalar:</div>
            <ul>
              <li v-for="m in membershipsPreview" :key="m.tenant_id">
                {{ m.tenant_name || m.tenant_slug || m.tenant_id }}
              </li>
            </ul>
          </div>
        </div>

        <div v-else class="registration-form">
          <form @submit.prevent="handleSubmit">
            <div class="form-group">
              <label for="firm-name">Firma Adi *</label>
              <input
                id="firm-name"
                v-model="formData.firm_name"
                type="text"
                required
                placeholder="Orn: ABC Teknoloji"
                maxlength="100"
              />
              <small>Firma adi, URL'de slug olarak kullanilacaktir.</small>
            </div>

            <div class="form-group">
              <label for="firm-owner-name">Firma Sahibi Adi</label>
              <input
                id="firm-owner-name"
                v-model="formData.firm_owner_name"
                type="text"
                placeholder="Istege bagli"
                maxlength="100"
              />
            </div>
            <div class="form-group">
              <label for="firm-city">Il</label>
              <select id="firm-city" v-model="formData.address.city">
                <option value="">Seciniz</option>
                <option v-for="city in cityOptions" :key="locationOptionValue(city)" :value="locationOptionValue(city)">
                  {{ locationOptionLabel(city) }}
                </option>
              </select>
            </div>

            <div class="form-group">
              <label for="firm-district">Ilce</label>
              <select id="firm-district" v-model="formData.address.district" :disabled="!formData.address.city">
                <option value="">Seciniz</option>
                <option v-for="district in districtOptions" :key="locationOptionValue(district)" :value="locationOptionValue(district)">
                  {{ locationOptionLabel(district) }}
                </option>
              </select>
            </div>

            <div class="form-group">
              <label for="firm-neighborhood">Mahalle</label>
              <select id="firm-neighborhood" v-model="formData.address.neighborhood" :disabled="!formData.address.city || !formData.address.district">
                <option value="">Seciniz</option>
                <option
                  v-for="neighborhood in neighborhoodOptions"
                  :key="locationOptionValue(neighborhood)"
                  :value="locationOptionValue(neighborhood)"
                >
                  {{ locationOptionLabel(neighborhood) }}
                </option>
              </select>
            </div>

            <div class="form-group">
              <label for="firm-street">Sokak / Cadde</label>
              <input id="firm-street" v-model.trim="formData.address.street" type="text" placeholder="Orn: Ihlamurdere Cd." maxlength="120" />
            </div>

            <div class="form-group">
              <label for="firm-building-no">Dis Kapi No</label>
              <input id="firm-building-no" v-model.trim="formData.address.building_no" type="text" placeholder="Orn: 14" maxlength="30" />
            </div>

            <div class="form-group">
              <label for="firm-door-no">Ic Kapi No</label>
              <input id="firm-door-no" v-model.trim="formData.address.door_no" type="text" placeholder="Orn: 5" maxlength="30" />
            </div>

            <div class="form-group">
              <label for="firm-address-line">Acik Adres</label>
              <input id="firm-address-line" v-model.trim="formData.address.address_line" type="text" placeholder="Detayli adres" maxlength="220" />
            </div>
            <ActionResultBox
              :loading="submitting"
              :error="error"
              :success="success"
              retry-text="Tekrar Dene"
              :on-retry="handleSubmit"
            />

            <div class="form-actions">
              <button type="submit" :disabled="loading || submitting" class="submit-btn">
                {{ submitting ? 'Olusturuluyor...' : 'Firma Olustur' }}
              </button>
              <router-link to="/account" class="cancel-link">Iptal</router-link>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client.js';
import { isLoggedIn, setActiveTenantId, getActiveTenantId } from '../lib/session.js';
import { normalizeApiError } from '../lib/errors/api_error.js';
import { notifyApiSuccess, notifyApiError } from '../lib/toast/notify_api.js';
import { getCityOptions, getDistrictOptions, getNeighborhoodOptions } from '../lib/catalogSpine.js';
import ActionResultBox from '../components/common/ActionResultBox.vue';

export default {
  name: 'FirmRegisterPage',
  components: { ActionResultBox },
  data() {
    return {
      formData: {
        firm_name: '',
        firm_owner_name: '',
        address: {
          city: '',
          district: '',
          neighborhood: '',
          street: '',
          building_no: '',
          door_no: '',
          address_line: '',
        },
      },
      loading: false,
      submitting: false,
      error: null,
      success: null,
      gateState: 'checking',
      preferredTenantId: null,
      membershipsPreview: [],
      cityOptions: [],
      districtOptions: [],
      neighborhoodOptions: [],
    };
  },
  watch: {
    'formData.address.city': {
      async handler(newCity, oldCity) {
        if (newCity === oldCity) return;
        this.formData.address.district = '';
        this.formData.address.neighborhood = '';
        this.districtOptions = [];
        this.neighborhoodOptions = [];
        if (!newCity) return;
        try {
          this.districtOptions = await getDistrictOptions(newCity);
        } catch {
          this.districtOptions = [];
        }
      },
    },
    'formData.address.district': {
      async handler(newDistrict, oldDistrict) {
        if (newDistrict === oldDistrict) return;
        this.formData.address.neighborhood = '';
        this.neighborhoodOptions = [];
        if (!this.formData.address.city || !newDistrict) return;
        try {
          this.neighborhoodOptions = await getNeighborhoodOptions(this.formData.address.city, newDistrict);
        } catch {
          this.neighborhoodOptions = [];
        }
      },
    },
  },
  computed: {
    isAuthenticated() {
      return isLoggedIn();
    },
  },
  async mounted() {
    if (!this.isAuthenticated) {
      this.$router.push('/login?reason=expired');
      return;
    }
    this.loading = true;
    try {
      this.cityOptions = await getCityOptions();
      const activeTenantId = getActiveTenantId();
      if (activeTenantId) {
        this.gateState = 'already_active';
        return;
      }

      const resp = await api.getMyMemberships();
      const items = resp?.items || resp?.data || (Array.isArray(resp) ? resp : []);
      if (Array.isArray(items) && items.length > 0) {
        const preferred = items.find((m) => m?.role === 'owner' || m?.role === 'admin') || items[0];
        this.preferredTenantId = preferred?.tenant_id || null;
        this.membershipsPreview = items.slice(0, 5).map((m) => ({
          tenant_id: m?.tenant_id,
          tenant_name: m?.tenant_name,
          tenant_slug: m?.tenant_slug,
        })).filter((m) => m.tenant_id);
        this.gateState = 'has_memberships';
        return;
      }

      this.gateState = 'needs_form';
    } catch {
      this.gateState = 'needs_form';
    } finally {
      this.loading = false;
    }
  },
  methods: {
    goToListingCreate() {
      this.$router.push('/listing/create');
    },
    activatePreferredAndContinue() {
      if (!this.preferredTenantId) return;
      setActiveTenantId(this.preferredTenantId);
      this.$router.push('/listing/create');
    },
    generateSlug(name) {
      return name
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '');
    },
    locationOptionLabel(option) {
      if (option && typeof option === 'object') return option.label || option.value || '';
      return String(option || '');
    },
    locationOptionValue(option) {
      if (option && typeof option === 'object') return option.value || option.label || '';
      return String(option || '');
    },
    buildAddressPayload() {
      const a = this.formData.address || {};
      const payload = {};
      ['city', 'district', 'neighborhood', 'street', 'building_no', 'door_no', 'address_line'].forEach((k) => {
        const v = typeof a[k] === 'string' ? a[k].trim() : '';
        if (v) payload[k] = v;
      });
      return payload;
    },
    async handleSubmit() {
      if (!this.formData.firm_name.trim()) {
        this.error = 'Firma adi gereklidir.';
        return;
      }

      this.submitting = true;
      this.error = null;
      this.success = null;

      try {
        const slug = this.generateSlug(this.formData.firm_name);
        if (!slug || slug.length < 3) {
          this.error = 'Firma adi slug uretilemedi. Lutfen sadece harf/rakam iceren bir firma adi girin (en az 3 karakter).';
          this.submitting = false;
          return;
        }
        const displayName = this.formData.firm_owner_name.trim() || this.formData.firm_name.trim();

        const response = await api.hosCreateTenant({
          slug,
          display_name: displayName,
        });

        if (response.tenant_id) {
          const addressPayload = this.buildAddressPayload();
          if (Object.keys(addressPayload).length > 0) {
            try {
              await api.hosUpsertTenantAddress(response.tenant_id, addressPayload);
            } catch (addrErr) {
              console.warn('Tenant address save failed during firm create:', addrErr);
            }
          }
          setActiveTenantId(response.tenant_id);

          this.success = `Firma basariyla olusturuldu! (${response.slug})`;
          notifyApiSuccess('Firm registered');

          await new Promise(resolve => setTimeout(resolve, 1500));
          this.$router.push('/listing/create');
        } else {
          this.error = 'Firma olusturulamadi. Lutfen tekrar deneyin.';
        }
      } catch (err) {
        const normalized = normalizeApiError(err);
        if (err.status === 401) {
          this.error = 'Oturum sureniz dolmus. Lutfen tekrar giris yapin.';
          setTimeout(() => {
            this.$router.push('/login?reason=expired');
          }, 2000);
        } else if (err.status === 409) {
          this.error = 'Bu firma adi zaten kullaniliyor. Lutfen farkli bir ad secin.';
        } else {
          this.error = normalized.message;
        }
        notifyApiError(err, 'Firm register');
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

.loading-message {
  background: #f8f9fa;
  padding: 2rem;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.loading-message p {
  margin: 0 0 0.5rem 0;
  color: #333;
}

.loading-message .muted {
  margin: 0;
  color: #666;
  font-size: 0.9rem;
}

.info-message {
  background: #f8f9fa;
  padding: 1.5rem;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.cta-row {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  margin-top: 1rem;
}

.primary-btn {
  padding: 0.75rem 1.25rem;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.primary-btn:hover {
  background: #0056b3;
}

.secondary-link {
  color: #0066cc;
  text-decoration: none;
}

.secondary-link:hover {
  text-decoration: underline;
}

.memberships-preview {
  margin-top: 1rem;
  color: #333;
}

.memberships-preview ul {
  margin: 0.5rem 0 0 1rem;
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

.form-group input,
.form-group select {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ced4da;
  border-radius: 4px;
  font-size: 1rem;
  box-sizing: border-box;
}

.form-group input:focus,
.form-group select:focus {
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
