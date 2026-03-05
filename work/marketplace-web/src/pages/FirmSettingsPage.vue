<template>
  <div class="firm-settings-page">
    <div class="header-row">
      <h2>Firma Ayarlari</h2>
      <router-link to="/firm" class="back-link">Firma Paneline Don</router-link>
    </div>

    <div v-if="!activeTenantId" class="warn-box">
      <p>Aktif firma secilmedi. Once Hesabim ekranindan firma secin.</p>
      <router-link to="/account" class="btn-primary">Hesaba Git</router-link>
    </div>

    <template v-else>
      <section class="card">
        <h3>Firma Bilgileri</h3>
        <div class="row"><strong>Firma ID:</strong> {{ activeTenantId }}</div>
        <div class="row"><strong>Firma Adi:</strong> {{ activeTenantName || '-' }}</div>
        <small class="muted">Firma adi (display_name) duzenleme endpointi henuz acik degil.</small>
      </section>

      <section class="card">
        <h3>Firma Adresi</h3>
        <div v-if="loading" class="muted">Adres verileri yukleniyor...</div>
        <div v-else class="grid">
          <label>
            Il
            <select v-model="form.city" class="form-input">
              <option value="">Seciniz</option>
              <option v-for="c in cityOptions" :key="c" :value="c">{{ c }}</option>
            </select>
          </label>

          <label>
            Ilce
            <select v-model="form.district" class="form-input" :disabled="!form.city">
              <option value="">Seciniz</option>
              <option v-for="d in districtOptions" :key="d" :value="d">{{ d }}</option>
            </select>
          </label>

          <label>
            Mahalle
            <select v-model="form.neighborhood" class="form-input" :disabled="!form.city || !form.district">
              <option value="">Seciniz</option>
              <option v-for="n in neighborhoodOptions" :key="n" :value="n">{{ n }}</option>
            </select>
          </label>

          <label>
            Sokak / Cadde
            <input v-model.trim="form.street" type="text" class="form-input" />
          </label>

          <label>
            Dis Kapi No
            <input v-model.trim="form.building_no" type="text" class="form-input" />
          </label>

          <label>
            Ic Kapi No
            <input v-model.trim="form.door_no" type="text" class="form-input" />
          </label>

          <label class="full">
            Acik Adres
            <input v-model.trim="form.address_line" type="text" class="form-input" />
          </label>
        </div>

        <div class="actions">
          <button type="button" class="btn-primary" :disabled="saving" @click="save">
            {{ saving ? 'Kaydediliyor...' : 'Kaydet' }}
          </button>
          <small v-if="saveError" class="warn-text">{{ saveError }}</small>
          <small v-if="saveOk" class="ok-text">Kaydedildi.</small>
        </div>
      </section>
    </template>
  </div>
</template>

<script>
import { api } from '../api/client.js';
import { getActiveTenantId } from '../lib/session.js';
import { getCityOptions, getDistrictOptions, getNeighborhoodOptions } from '../lib/catalogSpine.js';

export default {
  name: 'FirmSettingsPage',
  data() {
    return {
      activeTenantId: null,
      activeTenantName: null,
      loading: false,
      saving: false,
      saveOk: false,
      saveError: null,
      cityOptions: [],
      districtOptions: [],
      neighborhoodOptions: [],
      initializingAddress: false,
      form: {
        city: '',
        district: '',
        neighborhood: '',
        street: '',
        building_no: '',
        door_no: '',
        address_line: '',
      },
    };
  },
  watch: {
    'form.city': {
      async handler(newCity, oldCity) {
        if (newCity === oldCity) return;
        if (this.initializingAddress) return;
        this.form.district = '';
        this.form.neighborhood = '';
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
    'form.district': {
      async handler(newDistrict, oldDistrict) {
        if (newDistrict === oldDistrict) return;
        if (this.initializingAddress) return;
        this.form.neighborhood = '';
        this.neighborhoodOptions = [];
        if (!this.form.city || !newDistrict) return;
        try {
          this.neighborhoodOptions = await getNeighborhoodOptions(this.form.city, newDistrict);
        } catch {
          this.neighborhoodOptions = [];
        }
      },
    },
  },
  async mounted() {
    this.activeTenantId = getActiveTenantId();
    if (!this.activeTenantId) return;
    this.loading = true;
    try {
      const [memberships, cities, addrResp] = await Promise.all([
        api.getMyMemberships(),
        getCityOptions().catch(() => []),
        api.hosGetTenantAddress(this.activeTenantId).catch(() => ({ address: null })),
      ]);

      this.cityOptions = Array.isArray(cities) ? cities : [];
      const list = memberships?.items || memberships?.data || (Array.isArray(memberships) ? memberships : []);
      const active = Array.isArray(list) ? list.find((m) => m.tenant_id === this.activeTenantId) : null;
      this.activeTenantName = active ? (active.tenant_name || active.tenant_slug) : null;

      const a = addrResp?.address || {};
      this.initializingAddress = true;
      this.form = {
        city: String(a.city || '').trim(),
        district: String(a.district || '').trim(),
        neighborhood: String(a.neighborhood || '').trim(),
        street: String(a.street || '').trim(),
        building_no: String(a.building_no || '').trim(),
        door_no: String(a.door_no || '').trim(),
        address_line: String(a.address_line || '').trim(),
      };

      if (this.form.city) {
        this.districtOptions = await getDistrictOptions(this.form.city).catch(() => []);
      }
      if (this.form.city && this.form.district) {
        this.neighborhoodOptions = await getNeighborhoodOptions(this.form.city, this.form.district).catch(() => []);
      }
      this.initializingAddress = false;
    } finally {
      this.initializingAddress = false;
      this.loading = false;
    }
  },
  methods: {
    buildPayload() {
      const payload = {};
      ['city', 'district', 'neighborhood', 'street', 'building_no', 'door_no', 'address_line'].forEach((k) => {
        const v = typeof this.form[k] === 'string' ? this.form[k].trim() : '';
        if (v) payload[k] = v;
      });
      return payload;
    },
    async save() {
      if (!this.activeTenantId) return;
      this.saving = true;
      this.saveOk = false;
      this.saveError = null;
      try {
        await api.hosUpsertTenantAddress(this.activeTenantId, this.buildPayload());
        this.saveOk = true;
      } catch (err) {
        this.saveError = err?.message || 'Kaydetme basarisiz.';
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<style scoped>
.firm-settings-page {
  max-width: 1100px;
  margin: 0 auto;
  padding: 1rem 0 2rem 0;
}
.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}
.back-link {
  color: #2563eb;
  text-decoration: none;
}
.card {
  border: 1px solid #dde3ec;
  border-radius: 10px;
  background: #fff;
  padding: 1rem;
  margin-bottom: 1rem;
}
.row {
  margin-bottom: 0.4rem;
}
.muted {
  color: #6b7280;
}
.grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}
.form-input {
  width: 100%;
  padding: 0.55rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
}
.full {
  grid-column: 1 / -1;
}
.actions {
  margin-top: 0.9rem;
  display: flex;
  gap: 0.75rem;
  align-items: center;
}
.btn-primary {
  background: #0f766e;
  color: #fff;
  border: none;
  padding: 0.55rem 0.9rem;
  border-radius: 6px;
  cursor: pointer;
}
.warn-box {
  border: 1px solid #f59e0b;
  background: #fffbeb;
  padding: 1rem;
  border-radius: 8px;
}
.warn-text {
  color: #b45309;
}
.ok-text {
  color: #15803d;
  font-weight: 600;
}
</style>
