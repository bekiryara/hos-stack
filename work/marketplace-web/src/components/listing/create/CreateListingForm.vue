<template>
  <form @submit.prevent="onSubmit" class="listing-form">
    <div class="form-group">
      <label>
        Aktif Firma <span class="required">*</span>
        <div v-if="tenantId" class="tenant-id-display">
          <input
            :value="tenantId"
            type="text"
            required
            readonly
            class="form-input auto-filled"
          />
          <small class="auto-fill-note">Account sayfasından seçilen aktif firma kullanılır.</small>
        </div>
        <div v-else class="tenant-id-missing">
          <p class="tenant-id-warning">
            Bu işlem için aktif bir firmanız olmalı.
          </p>
          <div class="tenant-actions">
            <router-link to="/account" class="tenant-picker-link">Hesabıma Git</router-link>
            <router-link to="/firm/register" class="tenant-picker-link secondary">Firma Oluştur</router-link>
          </div>
          <small v-if="tenantIdLoadError" class="tenant-id-warning">
            <strong>Not:</strong> Aktif firma bulunamadı. Lütfen /account üzerinden firma oluşturun veya aktif firma seçin.
          </small>
        </div>
      </label>
    </div>

    <div class="form-group">
      <label class="category-label">
        Kategori <span class="required">*</span>
      </label>
      <CategoryPickerStepper
        v-model="local.category_id"
        :categories-tree="categoriesTree"
        mode="create"
        @category-change="emitCategoryChange"
        @gender-context="onGenderContext"
      />
    </div>

    <div class="form-group">
      <label>
        Title <span class="required">*</span>
        <input
          v-model="local.title"
          type="text"
          required
          maxlength="120"
          placeholder="Listing title (max 120 chars)"
          class="form-input"
        />
      </label>
    </div>

    <div class="form-group">
      <label>
        Description
        <textarea
          v-model="local.description"
          placeholder="Optional description"
          class="form-input"
          rows="4"
        />
      </label>
    </div>

    <div class="form-group">
      <label class="price-label">
        Fiyat
      </label>
      <div class="price-row">
        <input
          v-model.number="local.price_amount"
          type="number"
          min="0"
          step="1"
          placeholder="Fiyat"
          class="form-input"
        />
        <select v-model="local.currency" class="form-input price-currency">
          <option value="TRY">TRY</option>
          <option value="USD">USD</option>
          <option value="EUR">EUR</option>
        </select>
      </div>
      <small class="hint">
        Canonical fiyat alani. Eski attribute fiyatlari gecis icin ayrica kalabilir.
      </small>
    </div>

    <div class="form-group">
      <label>
        İlan Türü <span class="required">*</span>
        <select
          v-model="local.offer_variant"
          class="form-input"
          required
          :disabled="!intentSchema || !intentSchema.offer_variants || intentSchema.offer_variants.length === 0"
          @change="onOfferVariantChange"
        >
          <option value="" disabled>Seçiniz...</option>
          <option
            v-for="v in (intentSchema && intentSchema.offer_variants ? intentSchema.offer_variants : [])"
            :key="v.key"
            :value="v.key"
          >
            {{ v.label || v.key }}
          </option>
        </select>
        <small v-if="selectedOfferVariant" class="hint">
          <strong>Mode:</strong> {{ selectedOfferVariant.transaction_mode }}
          <span class="dot">•</span>
          <strong>Workflow:</strong> {{ selectedOfferVariant.interaction_mode }}
        </small>
      </label>
    </div>

    <div v-if="intentSchema" class="form-group">
      <label>Hizmet Modeli</label>
      <div class="primitive-grid">
        <div class="primitive-item">
          <strong>Fulfillment:</strong> {{ primitiveLabel('fulfillment_mode', intentSchema.fulfillment_mode) }}
        </div>
        <div class="primitive-item">
          <strong>Location Scope:</strong> {{ primitiveLabel('location_scope', intentSchema.location_scope) }}
        </div>
        <div class="primitive-item">
          <strong>Time Model:</strong> {{ primitiveLabel('service_time_model', intentSchema.service_time_model) }}
        </div>
        <div class="primitive-item">
          <strong>Offer Rule:</strong> {{ primitiveLabel('offer_requirement', intentSchema.offer_requirement) }}
        </div>
      </div>
      <small class="hint">Bu alanlar kategori policy'sinden gelir ve backend tarafinda zorlanir.</small>
    </div>

    <div v-if="intentSchema" class="form-group">
      <label>Konum Bilgisi</label>
      <div v-if="policyLocationScope === 'none'" class="hint-box">
        Bu kategoride konum gerekli degil.
      </div>

      <div v-else-if="policyLocationScope === 'city'" class="location-grid">
        <label>
          Il <span class="required">*</span>
          <select v-if="hasCityOptions" v-model="local.location.city" class="form-input">
            <option value="" disabled>Il seciniz...</option>
            <option v-for="c in cityOptions" :key="c" :value="c">{{ c }}</option>
          </select>
          <input v-else v-model.trim="local.location.city" type="text" class="form-input" placeholder="Orn: Izmir" />
        </label>
      </div>

      <div v-else-if="policyLocationScope === 'point'" class="location-grid">
        <div class="full-width tenant-address-use">
          <button type="button" class="minor-btn" @click="applyTenantAddress" :disabled="!hasTenantAddress">
            Firma adresini kullan
          </button>
          <small v-if="!hasTenantAddress" class="hint">Aktif firma icin kayitli adres bulunamadi.</small>
        </div>
        <label>
          Il <span class="required">*</span>
          <select v-if="hasCityOptions" v-model="local.location.city" class="form-input">
            <option value="" disabled>Il seciniz...</option>
            <option v-for="c in cityOptions" :key="c" :value="c">{{ c }}</option>
          </select>
          <input v-else v-model.trim="local.location.city" type="text" class="form-input" placeholder="Orn: Izmir" />
        </label>
        <label>
          Ilce <span class="required">*</span>
          <select v-if="hasDistrictOptions" v-model="local.location.district" class="form-input">
            <option value="" disabled>Ilce seciniz...</option>
            <option v-for="d in districtOptions" :key="d" :value="d">{{ d }}</option>
          </select>
          <input v-else v-model.trim="local.location.district" type="text" class="form-input" placeholder="Orn: Bornova" />
        </label>
        <label>
          Mahalle <span class="required">*</span>
          <select v-if="hasNeighborhoodOptions" v-model="local.location.neighborhood" class="form-input">
            <option value="" disabled>Mahalle seciniz...</option>
            <option v-for="n in neighborhoodOptions" :key="n" :value="n">{{ n }}</option>
          </select>
          <input v-else v-model.trim="local.location.neighborhood" type="text" class="form-input" placeholder="Orn: Kazimdirik Mah." />
        </label>
        <label>
          Sokak / Cadde
          <input v-model.trim="local.location.street" type="text" class="form-input" placeholder="Orn: 372. Sokak" />
        </label>
        <label>
          Dis Kapi No
          <input v-model.trim="local.location.building_no" type="text" class="form-input" placeholder="Orn: 12A" />
        </label>
        <label>
          Ic Kapi No
          <input v-model.trim="local.location.door_no" type="text" class="form-input" placeholder="Orn: 5" />
        </label>
        <label class="full-width">
          Acik Adres
          <input v-model.trim="local.location.address_line" type="text" class="form-input" placeholder="Mahalle, sokak, no..." />
        </label>
        <label>
          Enlem
          <input v-model.trim="local.location.lat" type="number" step="any" class="form-input" placeholder="38.4237" />
        </label>
        <label>
          Boylam
          <input v-model.trim="local.location.lng" type="number" step="any" class="form-input" placeholder="27.1428" />
        </label>
      </div>

      <div v-else-if="policyLocationScope === 'service_area'" class="service-area-editor">
        <div
          v-for="(row, idx) in local.location.service_area"
          :key="idx"
          class="service-area-row"
        >
          <div class="location-grid">
            <label>
              Il <span class="required">*</span>
              <select v-if="hasCityOptions" v-model="row.city" class="form-input">
                <option value="" disabled>Il seciniz...</option>
                <option v-for="c in cityOptions" :key="c" :value="c">{{ c }}</option>
              </select>
              <input v-else v-model.trim="row.city" type="text" class="form-input" placeholder="Orn: Manisa" />
            </label>
            <label class="checkbox-inline">
              <input v-model="row.all_districts" type="checkbox" />
              Tum il
            </label>
            <label v-if="!row.all_districts" class="full-width">
              Ilceler (virgulle ayir)
              <input v-model.trim="row.districts_text" type="text" class="form-input" placeholder="Turgutlu, Salihli" />
            </label>
          </div>
          <button type="button" class="minor-btn danger" @click="removeServiceAreaRow(idx)">Bolgeyi Sil</button>
        </div>
        <button type="button" class="minor-btn" @click="addServiceAreaRow">+ Il Ekle</button>
      </div>
    </div>

    <div v-if="filterSchema && filterSchema.filters" class="form-group">
      <h3>Attributes (from filter-schema)</h3>
      <small v-if="hiddenFiltersCount > 0" class="hint">
        Bu ilan türünde geçerli olmayan {{ hiddenFiltersCount }} alan gizlendi. Değerleriniz silinmedi.
      </small>
      <div
        v-for="filter in visibleFilters"
        :key="filter.attribute_key"
        class="attribute-field"
      >
        <FilterField
          :filter="filter"
          mode="create"
          v-model="local.attributes[filter.attribute_key]"
        />
      </div>
    </div>

    <div v-if="submitAttempted && submitErrors.length > 0" class="submit-errors">
      <div v-for="(msg, idx) in submitErrors" :key="idx">{{ msg }}</div>
    </div>

    <button type="submit" :disabled="loading || !tenantId" class="submit-button">
      {{ loading ? 'Creating...' : 'Create Listing (DRAFT)' }}
    </button>
  </form>
</template>

<script>
import CategoryPickerStepper from '../../catalog/CategoryPickerStepper.vue';
import FilterField from '../../common/FilterField.vue';
import { isLegacyPriceAttributeKey } from '../../../lib/pricing.js';

export default {
  name: 'CreateListingForm',
  components: {
    CategoryPickerStepper,
    FilterField,
  },
  props: {
    categoriesTree: { type: Array, default: () => [] },
    filterSchema: { type: Object, default: null },
    intentSchema: { type: Object, default: null },
    cityOptions: { type: Array, default: () => [] },
    districtOptions: { type: Array, default: () => [] },
    neighborhoodOptions: { type: Array, default: () => [] },
    tenantAddress: { type: Object, default: null },
    tenantId: { type: String, default: '' },
    tenantIdLoadError: { type: Boolean, default: false },
    loading: { type: Boolean, default: false },
  },
  emits: ['category-change', 'location-city-change', 'location-district-change', 'submit'],
  data() {
    return {
      local: {
        category_id: '',
        title: '',
        description: '',
        price_amount: null,
        currency: 'TRY',
        transaction_modes: [],
        offer_variant: '',
        attributes: {},
        location: {
          city: '',
          district: '',
          neighborhood: '',
          street: '',
          building_no: '',
          door_no: '',
          address_line: '',
          lat: '',
          lng: '',
          service_area: [{ city: '', all_districts: false, districts_text: '' }],
        },
      },
      submitAttempted: false,
      applyingTenantAddress: false,
    };
  },
  computed: {
    selectedOfferVariant() {
      const schema = this.intentSchema;
      const key = this.local.offer_variant || '';
      const list = schema && Array.isArray(schema.offer_variants) ? schema.offer_variants : [];
      return list.find((v) => v && v.key === key) || null;
    },
    currentTransactionMode() {
      const v = this.selectedOfferVariant;
      if (v && v.transaction_mode) return String(v.transaction_mode);
      const modes = Array.isArray(this.local.transaction_modes) ? this.local.transaction_modes : [];
      if (modes.length > 0 && modes[0]) return String(modes[0]);
      return 'sale';
    },
    visibleFilters() {
      const schema = this.filterSchema;
      const list = schema && Array.isArray(schema.filters) ? schema.filters : [];
      return list.filter((f) => {
        if (!this.isApplicableForMode(f, this.currentTransactionMode)) return false;
        if (isLegacyPriceAttributeKey(f?.attribute_key)) return false;
        if (this.shouldHideLegacyCityFilter && String(f?.attribute_key || '') === 'city') return false;
        return true;
      });
    },
    hiddenFiltersCount() {
      const schema = this.filterSchema;
      const list = schema && Array.isArray(schema.filters) ? schema.filters : [];
      return list.length - this.visibleFilters.length;
    },
    policyTimeModel() {
      return String(this.intentSchema?.service_time_model || '');
    },
    policyLocationScope() {
      return String(this.intentSchema?.location_scope || '');
    },
    policyOfferRule() {
      return String(this.intentSchema?.offer_requirement || '');
    },
    shouldHideLegacyCityFilter() {
      return ['city', 'point', 'service_area'].includes(this.policyLocationScope);
    },
    hasCityOptions() {
      return Array.isArray(this.cityOptions) && this.cityOptions.length > 0;
    },
    hasDistrictOptions() {
      return Array.isArray(this.districtOptions) && this.districtOptions.length > 0;
    },
    hasNeighborhoodOptions() {
      return Array.isArray(this.neighborhoodOptions) && this.neighborhoodOptions.length > 0;
    },
    hasTenantAddress() {
      const a = this.tenantAddress || {};
      return Boolean(
        String(a.city || '').trim() ||
        String(a.district || '').trim() ||
        String(a.neighborhood || '').trim() ||
        String(a.street || '').trim() ||
        String(a.building_no || '').trim() ||
        String(a.door_no || '').trim() ||
        String(a.address_line || '').trim()
      );
    },
    submitErrors() {
      return this.validateIntentCompatibility();
    },
  },
  watch: {
    intentSchema: {
      handler(newSchema) {
        this.submitAttempted = false;
        const list = newSchema && Array.isArray(newSchema.offer_variants) ? newSchema.offer_variants : [];
        if (list.length === 0) return;
        if (this.local.offer_variant) return;
        const defKey = (newSchema && newSchema.default_offer_variant) ? String(newSchema.default_offer_variant) : '';
        const fallback = defKey && list.find((v) => v && v.key === defKey) ? defKey : String(list[0].key);
        this.local.offer_variant = fallback;
        this.applyOfferVariant();
      },
      immediate: true,
    },
    'local.location.city'(value, oldValue) {
      if (String(value || '') === String(oldValue || '')) return;
      if (this.applyingTenantAddress) return;
      this.local.location.district = '';
      this.local.location.neighborhood = '';
      this.$emit('location-city-change', value || '');
      this.$emit('location-district-change', { city: value || '', district: '' });
    },
    'local.location.district'(value, oldValue) {
      if (String(value || '') === String(oldValue || '')) return;
      if (this.applyingTenantAddress) return;
      this.local.location.neighborhood = '';
      this.$emit('location-district-change', {
        city: this.local.location.city || '',
        district: value || '',
      });
    },
  },
  methods: {
    primitiveLabel(kind, value) {
      const raw = String(value || '');
      const dict = {
        fulfillment_mode: {
          provider_location: 'Saglayici lokasyonunda',
          customer_location: 'Musteri lokasyonunda',
          remote: 'Uzaktan',
          hybrid: 'Hibrit',
        },
        location_scope: {
          none: 'Konum gerekmiyor',
          city: 'Sehir seviyesi',
          point: 'Nokta adres',
          service_area: 'Servis bolgesi',
        },
        service_time_model: {
          none: 'Zaman modeli yok',
          date_range: 'Tarih araligi',
          slot: 'Randevu slotu',
          session: 'Seans',
        },
        offer_requirement: {
          no_offer: 'Paket gerekmiyor',
          optional_offer: 'Paket opsiyonel',
          required_offer: 'Paket zorunlu',
        },
      };
      const map = dict[kind] || {};
      return map[raw] || raw || '-';
    },
    // Faz-2: schema-driven applicability (hardcode yok).
    // Semantics: applies_to_transaction_modes is null/empty => applies to all modes.
    isApplicableForMode(filter, mode) {
      const m = mode ? String(mode) : '';
      if (!m) return true;
      const raw = filter && filter.applies_to_transaction_modes;
      if (!raw) return true;
      if (!Array.isArray(raw)) return true;
      if (raw.length === 0) return true;
      return raw.map(String).includes(m);
    },
    emitCategoryChange() {
      this.submitAttempted = false;
      this.local.offer_variant = '';
      this.local.transaction_modes = [];
      this.local.location = {
        city: '',
        district: '',
        neighborhood: '',
        street: '',
        building_no: '',
        door_no: '',
        address_line: '',
        lat: '',
        lng: '',
        service_area: [{ city: '', all_districts: false, districts_text: '' }],
      };
      if (this.local.attributes) {
        delete this.local.attributes.offer_variant;
        delete this.local.attributes.interaction_mode;
      }
      this.$emit('category-change', this.local.category_id);
    },
    onGenderContext(gender) {
      this.local.attributes = this.local.attributes || {};
      if (gender) {
        this.local.attributes.gender_context = gender;
      } else {
        delete this.local.attributes.gender_context;
      }
    },
    onOfferVariantChange() {
      this.applyOfferVariant();
    },
    applyOfferVariant() {
      const v = this.selectedOfferVariant;
      if (!v) return;
      const mode = v.transaction_mode || 'sale';
      this.local.transaction_modes = [mode];
      this.local.attributes = this.local.attributes || {};
      this.local.attributes.offer_variant = v.key;
      this.local.attributes.interaction_mode = (v.interaction_mode === 'flow') ? 'flow' : 'contact_only';
    },
    validateIntentCompatibility() {
      const errors = [];
      const mode = this.currentTransactionMode;
      const timeModel = this.policyTimeModel;
      const offerRule = this.policyOfferRule;

      if (mode === 'reservation' && !['slot', 'session'].includes(timeModel)) {
        errors.push('Bu kategoride reservation icin Time Model slot veya session olmalidir.');
      }
      if (mode === 'rental' && !['none', 'date_range'].includes(timeModel)) {
        errors.push('Bu kategoride rental icin Time Model none veya date_range olmalidir.');
      }
      if (mode === 'sale' && timeModel !== 'none') {
        errors.push('Bu kategoride sale icin Time Model none olmalidir.');
      }
      if ((mode === 'sale' || mode === 'rental') && offerRule === 'required_offer') {
        errors.push('Bu kategoride required_offer su anda sale/rental akisinda desteklenmiyor.');
      }

      errors.push(...this.validateLocationInputs());
      return errors;
    },
    parseDistricts(text) {
      return String(text || '')
        .split(',')
        .map((v) => v.trim())
        .filter((v) => v.length > 0);
    },
    validateLocationInputs() {
      const errors = [];
      const scope = this.policyLocationScope;
      const loc = this.local.location || {};
      if (scope === 'none') return errors;

      if (scope === 'city') {
        if (!String(loc.city || '').trim()) {
          errors.push('Bu kategoride il bilgisi zorunludur.');
        }
      }

      if (scope === 'point') {
        if (!String(loc.city || '').trim()) errors.push('Bu kategoride il bilgisi zorunludur.');
        if (!String(loc.district || '').trim()) errors.push('Bu kategoride ilce bilgisi zorunludur.');
        if (!String(loc.neighborhood || '').trim()) errors.push('Bu kategoride mahalle bilgisi zorunludur.');
      }

      if (scope === 'service_area') {
        const rows = Array.isArray(loc.service_area) ? loc.service_area : [];
        if (rows.length === 0) {
          errors.push('En az bir hizmet bolgesi girilmelidir.');
        } else {
          const validRows = rows.filter((r) => String(r?.city || '').trim().length > 0);
          if (validRows.length === 0) {
            errors.push('Service area icin en az bir il zorunludur.');
          }
          validRows.forEach((r) => {
            if (!r.all_districts && this.parseDistricts(r.districts_text).length === 0) {
              errors.push(`"${r.city}" icin tum il secili degilse en az bir ilce girilmelidir.`);
            }
          });
        }
      }
      return errors;
    },
    buildLocationPayload() {
      const scope = this.policyLocationScope;
      const loc = this.local.location || {};
      if (scope === 'none') return null;

      if (scope === 'city') {
        return { city: String(loc.city || '').trim() };
      }

      if (scope === 'point') {
        const payload = {
          city: String(loc.city || '').trim(),
          district: String(loc.district || '').trim(),
          neighborhood: String(loc.neighborhood || '').trim(),
        };
        const street = String(loc.street || '').trim();
        if (street) payload.street = street;
        const buildingNo = String(loc.building_no || '').trim();
        if (buildingNo) payload.building_no = buildingNo;
        const doorNo = String(loc.door_no || '').trim();
        if (doorNo) payload.door_no = doorNo;
        const addressLine = String(loc.address_line || '').trim();
        if (addressLine) payload.address_line = addressLine;
        const lat = String(loc.lat || '').trim();
        const lng = String(loc.lng || '').trim();
        if (lat && lng && Number.isFinite(Number(lat)) && Number.isFinite(Number(lng))) {
          payload.lat = Number(lat);
          payload.lng = Number(lng);
        }
        return payload;
      }

      if (scope === 'service_area') {
        const rows = Array.isArray(loc.service_area) ? loc.service_area : [];
        return {
          service_area: rows
            .map((r) => ({
              city: String(r?.city || '').trim(),
              all_districts: Boolean(r?.all_districts),
              districts: Boolean(r?.all_districts) ? [] : this.parseDistricts(r?.districts_text),
            }))
            .filter((r) => r.city),
        };
      }
      return null;
    },
    addServiceAreaRow() {
      if (!Array.isArray(this.local.location.service_area)) {
        this.local.location.service_area = [];
      }
      this.local.location.service_area.push({ city: '', all_districts: false, districts_text: '' });
    },
    removeServiceAreaRow(index) {
      const rows = this.local.location.service_area || [];
      if (!Array.isArray(rows)) return;
      if (rows.length <= 1) {
        rows[0] = { city: '', all_districts: false, districts_text: '' };
        return;
      }
      rows.splice(index, 1);
    },
    async applyTenantAddress() {
      if (!this.hasTenantAddress) return;
      const a = this.tenantAddress || {};
      this.applyingTenantAddress = true;
      this.local.location.city = String(a.city || '').trim();
      this.local.location.district = String(a.district || '').trim();
      this.local.location.neighborhood = String(a.neighborhood || '').trim();
      this.local.location.street = String(a.street || '').trim();
      this.local.location.building_no = String(a.building_no || '').trim();
      this.local.location.door_no = String(a.door_no || '').trim();
      this.local.location.address_line = String(a.address_line || '').trim();
      if (a.lat != null && a.lng != null && Number.isFinite(Number(a.lat)) && Number.isFinite(Number(a.lng))) {
        this.local.location.lat = String(a.lat);
        this.local.location.lng = String(a.lng);
      }
      this.$emit('location-city-change', this.local.location.city || '');
      await this.$nextTick();
      this.$emit('location-district-change', {
        city: this.local.location.city || '',
        district: this.local.location.district || '',
      });
      this.applyingTenantAddress = false;
    },
    onSubmit() {
      this.submitAttempted = true;
      if (this.submitErrors.length > 0) {
        return;
      }
      const visibleKeys = new Set((this.visibleFilters || []).map((f) => String(f.attribute_key)));
      visibleKeys.add('offer_variant');
      visibleKeys.add('interaction_mode');
      visibleKeys.add('gender_context');

      const rawAttrs = this.local.attributes && typeof this.local.attributes === 'object' ? this.local.attributes : {};
      const filteredAttrs = {};
      Object.keys(rawAttrs).forEach((k) => {
        if (visibleKeys.has(String(k))) {
          filteredAttrs[k] = rawAttrs[k];
        }
      });
      const locationPayload = this.buildLocationPayload();

      const snapshot = {
        category_id: this.local.category_id,
        title: this.local.title,
        description: this.local.description,
        price_amount: this.local.price_amount,
        currency: this.local.currency || 'TRY',
        transaction_modes: [...(this.local.transaction_modes || [])],
        location: locationPayload,
        // Submit only visible attrs (do not delete hidden values from local state).
        attributes: filteredAttrs,
      };
      this.$emit('submit', snapshot);
    },
  },
};
</script>

<style scoped>
.listing-form {
  margin-top: 2rem;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.required {
  color: #d32f2f;
}

.form-input {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
}

.form-checkbox {
  width: auto;
  margin-right: 0.5rem;
}

.checkbox-group {
  display: flex;
  gap: 1rem;
  margin-top: 0.5rem;
}

.checkbox-group label {
  display: flex;
  align-items: center;
  font-weight: normal;
}

.hint {
  display: block;
  margin-top: 0.35rem;
  color: #666;
  font-size: 0.875rem;
}

.price-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 140px;
  gap: 0.75rem;
}

.price-currency {
  min-width: 0;
}

.dot {
  margin: 0 0.35rem;
  color: #999;
}

.required-badge {
  display: inline-block;
  background: #ff9800;
  color: white;
  font-size: 0.75rem;
  padding: 0.2rem 0.5rem;
  border-radius: 3px;
  margin-left: 0.5rem;
}

.type-badge {
  display: inline-block;
  background: #e3f2fd;
  color: #1976d2;
  font-size: 0.75rem;
  padding: 0.2rem 0.5rem;
  border-radius: 3px;
  margin-left: 0.5rem;
}

.attribute-field {
  margin-bottom: 1rem;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
}

.location-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}

.full-width {
  grid-column: 1 / -1;
}

.hint-box {
  padding: 0.65rem 0.75rem;
  border: 1px solid #dbeafe;
  border-left: 3px solid #2563eb;
  background: #eff6ff;
  border-radius: 4px;
  color: #1e3a8a;
  font-size: 0.9rem;
}

.service-area-editor {
  display: grid;
  gap: 0.75rem;
}

.service-area-row {
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  padding: 0.75rem;
  background: #fafafa;
}

.checkbox-inline {
  display: flex !important;
  align-items: center;
  gap: 0.5rem;
  font-weight: 500;
}

.minor-btn {
  background: #f3f4f6;
  border: 1px solid #d1d5db;
  color: #111827;
  padding: 0.45rem 0.7rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.85rem;
}

.minor-btn.danger {
  background: #fef2f2;
  border-color: #fecaca;
  color: #b91c1c;
}

.submit-errors {
  margin-top: 0.5rem;
  margin-bottom: 0.5rem;
  color: #b71c1c;
  background: #ffebee;
  border: 1px solid #ffcdd2;
  border-left: 3px solid #c62828;
  border-radius: 4px;
  padding: 0.65rem 0.75rem;
  font-size: 0.9rem;
}

.primitive-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.5rem;
}

.primitive-item {
  background: #f5f7fa;
  border: 1px solid #e1e5ea;
  border-radius: 4px;
  padding: 0.55rem 0.65rem;
  font-size: 0.92rem;
}

.submit-button {
  background: #0066cc;
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
  margin-top: 1rem;
}

.submit-button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.submit-button:hover:not(:disabled) {
  background: #0052a3;
}

.tenant-id-display {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.tenant-id-missing {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.tenant-picker-link {
  color: #0066cc;
  text-decoration: underline;
  font-weight: 500;
}

.auto-filled {
  background-color: #f5f5f5 !important;
  cursor: not-allowed;
}

.auto-fill-note {
  color: #666;
  display: block;
  margin-top: 0.25rem;
  font-size: 0.875rem;
}

.tenant-id-warning {
  color: #f57c00;
  display: block;
  margin-top: 0.5rem;
  font-size: 0.875rem;
  background: #fff3e0;
  padding: 0.5rem;
  border-radius: 4px;
  border-left: 3px solid #ff9800;
}

.category-label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}
</style>
