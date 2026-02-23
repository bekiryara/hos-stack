<template>
  <div class="listing-detail-page">
    <div v-if="loading" class="loading">Loading listing...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else-if="listing" class="listing-detail">
      <h2>{{ listing.title || 'Untitled Listing' }}</h2>
      <div class="detail-section">
        <h3>Basic Info</h3>
        <p><strong>ID:</strong> {{ listing.id }}</p>
        <p><strong>Status:</strong> {{ listing.status }}</p>
        <div v-if="listing.transaction_modes && listing.transaction_modes.length > 0" class="transaction-modes">
          <strong>Transaction Modes:</strong>
          <div class="transaction-badges">
            <span
              v-for="mode in listing.transaction_modes"
              :key="mode"
              class="transaction-badge"
              :class="`transaction-badge-${mode}`"
            >
              {{ mode.charAt(0).toUpperCase() + mode.slice(1) }}
            </span>
          </div>
        </div>
      </div>
      <div class="detail-section">
        <h3>Category</h3>
        <p v-if="listing.category_id">
          <strong>Category:</strong>
          <template v-if="categoryName">{{ categoryName }} (ID: {{ listing.category_id }})</template>
          <template v-else>Category ID: {{ listing.category_id }}</template>
        </p>
        <p v-else><strong>Category ID:</strong> —</p>
      </div>
      <div class="detail-section">
        <h3>Attributes</h3>
        <p v-if="!sortedAttributeKeys.length">No attributes</p>
        <ul v-else class="attributes-list">
          <li v-for="key in sortedAttributeKeys" :key="key"><strong>{{ key }}:</strong> {{ renderAttributeValue(normalizedAttributes[key]) }}</li>
        </ul>
      </div>
      <div v-if="listing.supports_packages" class="detail-section">
        <h3>Paketler (Offers)</h3>
        <p class="muted">
          Bu bölüm sadece tıklayınca yüklenir (sistemi zorlamaz).
        </p>
        <div class="offers-actions">
          <button
            type="button"
            class="action-button"
            :disabled="offersLoading || offersLoaded"
            @click="loadOffers"
          >
            <template v-if="offersLoaded">Paketler yüklendi</template>
            <template v-else-if="offersLoading">Yükleniyor...</template>
            <template v-else>Paketleri Göster</template>
          </button>
        </div>
        <div v-if="offersError" class="error">{{ offersError }}</div>
        <div v-else-if="offersLoaded">
          <p v-if="!offers || offers.length === 0">Bu ilan için paket yok</p>
          <ul v-else class="offers-list">
            <li v-for="o in offers" :key="o.id" class="offer-item">
              <div class="offer-title">
                <strong>{{ o.name }}</strong>
                <span class="muted">({{ o.code }})</span>
              </div>
              <div class="muted">
                {{ o.price_amount }} {{ o.price_currency }} • {{ o.billing_model }}
              </div>
              <div v-if="o.attributes && o.attributes.includes">
                <strong>Dahil:</strong> {{ Array.isArray(o.attributes.includes) ? o.attributes.includes.join(', ') : o.attributes.includes }}
              </div>
              <details v-if="o.attributes" class="offer-details">
                <summary>attributes</summary>
                <pre class="full-json">{{ JSON.stringify(o.attributes, null, 2) }}</pre>
              </details>
            </li>
          </ul>
        </div>
      </div>
      <div v-if="listing" class="detail-section">
        <h3>Full Data</h3>
        <pre class="full-json">{{ JSON.stringify(listing, null, 2) }}</pre>
      </div>
      <div class="actions">
        <button
          v-for="a in resolvedActions"
          :key="a.key"
          type="button"
          class="action-button"
          @click="runAction(a)"
        >
          {{ a.label }}
        </button>
      </div>
      
      <div v-if="listing && listing.status === 'draft'" class="publish-section">
        <h3>Publish Listing</h3>
        <PublishListingAction :listing-id="listing.id" @published="handlePublished" />
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client';
import { getCategoriesTree } from '../lib/catalogSpine';
import { resolveListingActions } from '../lib/listingActions';
import { categoryLabel, findCategoryById } from '../lib/categoryTree';
import PublishListingAction from '../components/PublishListingAction.vue';

export default {
  name: 'ListingDetailPage',
  components: {
    PublishListingAction,
  },
  props: {
    id: {
      type: String,
      required: true,
    },
  },
  computed: {
    normalizedAttributes() {
      const listing = this.listing;
      const attrs = (listing && listing.attributes && typeof listing.attributes === 'object')
        ? listing.attributes
        : {};
      return attrs;
    },
    sortedAttributeKeys() {
      return Object.keys(this.normalizedAttributes).sort();
    },
    resolvedActions() {
      if (!this.listing) return [];
      return resolveListingActions(this.listing, { context: 'detail' });
    },
  },
  data() {
    return {
      listing: null,
      loading: true,
      error: null,
      categoryName: null,
      offers: [],
      offersLoading: false,
      offersLoaded: false,
      offersError: null,
    };
  },
  async mounted() {
    await this.loadListing();
  },
  methods: {
    renderAttributeValue(value) {
      if (value === null || value === undefined || value === '') return '—';
      if (value === 0 || value === false) return value;
      if (Array.isArray(value)) {
        return value.map((v) => (v != null && typeof v === 'object' ? JSON.stringify(v) : v)).join(', ');
      }
      if (typeof value === 'object') {
        try {
          return JSON.stringify(value);
        } catch {
          return '[object]';
        }
      }
      return value;
    },
    async loadListing() {
      try {
        this.listing = await api.getListing(this.id);
        if (this.listing?.category_id) {
          try {
            const tree = await getCategoriesTree();
            const nodes = Array.isArray(tree) ? tree : (tree?.items ?? []);
            const found = findCategoryById(nodes, this.listing.category_id);
            this.categoryName = found ? (categoryLabel(found) || String(found.id)) : null;
          } catch {
            this.categoryName = null;
          }
        }
        this.loading = false;
      } catch (err) {
        // WP-62: Better error handling for 404 and other errors
        if (err.status === 404) {
          this.error = `Listing not found (ID: ${this.id})`;
        } else if (err.status) {
          this.error = `Error ${err.status}: ${err.message || 'Unknown error'}`;
        } else {
          this.error = err.message || 'Failed to load listing';
        }
        this.loading = false;
      }
    },
    async loadOffers() {
      // Avoid background load; only fetch on user action.
      if (this.offersLoading || this.offersLoaded) return;
      try {
        this.offersLoading = true;
        this.offersError = null;
        const data = await api.getListingOffers(this.id);
        this.offers = Array.isArray(data) ? data : [];
        this.offersLoaded = true;
      } catch (err) {
        const msg = err?.message || 'Failed to load offers';
        this.offersError = msg;
        this.offersLoaded = true; // loaded (but failed) prevents retry loops; user can refresh page if needed
      } finally {
        this.offersLoading = false;
      }
    },
    handlePublished(updatedListing) {
      this.listing = updatedListing;
    },
    runAction(action) {
      if (!action || !action.to) return;
      this.$router.push(action.to);
    },
  },
};
</script>

<style scoped>
.listing-detail-page {
  max-width: 900px;
}

.listing-detail h2 {
  margin-bottom: 1.5rem;
  font-size: 2rem;
}

.detail-section {
  margin-bottom: 2rem;
  padding: 1.5rem;
  background: #f9f9f9;
  border-radius: 8px;
}

.detail-section h3 {
  margin-bottom: 1rem;
  font-size: 1.3rem;
}

.detail-section p {
  margin-bottom: 0.5rem;
}

.muted {
  color: #666;
  font-size: 0.95rem;
}

.offers-actions {
  margin: 0.75rem 0 0.5rem;
}

.offers-list {
  list-style: none;
  padding: 0;
  margin: 0.75rem 0 0;
}

.offer-item {
  padding: 0.75rem;
  background: #fff;
  border: 1px solid #eee;
  border-radius: 6px;
  margin-bottom: 0.75rem;
}

.offer-title {
  margin-bottom: 0.25rem;
}

.offer-details {
  margin-top: 0.5rem;
}

.attributes-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.attributes-list li {
  margin-bottom: 0.25rem;
}

.attributes-json,
.full-json {
  background: #f5f5f5;
  padding: 1rem;
  border-radius: 4px;
  overflow-x: auto;
  font-size: 0.9rem;
  line-height: 1.5;
}

.actions {
  margin-top: 2rem;
  display: flex;
  gap: 1rem;
}

.action-button {
  padding: 0.75rem 1.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: #0066cc;
  color: white;
  cursor: pointer;
  font-size: 1rem;
  text-decoration: none;
  display: inline-block;
  margin-right: 0.5rem;
}

.action-button:hover {
  background: #0052a3;
}

.action-button:disabled {
  background: #f5f5f5;
  color: #999;
  cursor: not-allowed;
}

.publish-section {
  margin-top: 2rem;
  padding: 1.5rem;
  background: #f9f9f9;
  border-radius: 8px;
}

.publish-section h3 {
  margin-bottom: 1rem;
}

.transaction-modes {
  margin-top: 1rem;
}

.transaction-modes strong {
  display: block;
  margin-bottom: 0.5rem;
}

.transaction-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.transaction-badge {
  display: inline-block;
  padding: 0.4rem 0.8rem;
  border-radius: 4px;
  font-size: 0.9rem;
  font-weight: 500;
  text-transform: capitalize;
}

.transaction-badge-reservation {
  background: #e3f2fd;
  color: #1976d2;
}

.transaction-badge-rental {
  background: #f3e5f5;
  color: #7b1fa2;
}

.transaction-badge-sale {
  background: #e8f5e9;
  color: #388e3c;
}
</style>

