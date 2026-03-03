<template>
  <div class="listing-detail-page">
    <div v-if="loading" class="loading">Loading listing...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else-if="listing && projection" class="listing-detail">
      <h2>{{ projection.hero.title }}</h2>

      <div v-if="projection.hero.primaryContextLine" class="context-line">
        {{ projection.hero.primaryContextLine }}
      </div>

      <div v-if="projection.hero.price" class="price-banner">
        {{ formatPrice(projection.hero.price, projection.hero.priceCurrency) }}
      </div>

      <div v-if="projection.hero.status && projection.hero.status !== 'published'" class="detail-meta">
        <span class="meta-tag meta-status" :class="`meta-status-${projection.hero.status}`">{{ projection.hero.status }}</span>
      </div>

      <div v-if="projection.summaryRows.length" class="detail-section">
        <h3>Ozet</h3>
        <ul class="attributes-list">
          <li v-for="row in projection.summaryRows" :key="row.key">
            <strong>{{ row.label }}:</strong> {{ row.value }}
          </li>
        </ul>
      </div>

      <div v-if="projection.description" class="detail-section">
        <h3>Aciklama</h3>
        <p>{{ projection.description }}</p>
      </div>

      <div class="detail-section">
        <h3>Ilan Ozellikleri</h3>
        <p v-if="!projection.featureRows.length">Gosterilecek ilan ozelligi yok</p>
        <ul v-else class="attributes-list">
          <li v-for="row in projection.featureRows" :key="row.key">
            <strong>{{ row.label }}:</strong> {{ row.value }}
          </li>
        </ul>
      </div>

      <div v-if="projection.contextRows.length" class="detail-section">
        <h3>Ilan Baglami</h3>
        <ul class="attributes-list">
          <li v-for="row in projection.contextRows" :key="row.key">
            <strong>{{ row.label }}:</strong> {{ row.value }}
          </li>
        </ul>
      </div>

      <div v-if="projection.policyRows.length" class="detail-section">
        <h3>Islem Bilgisi</h3>
        <ul class="attributes-list">
          <li v-for="row in projection.policyRows" :key="row.key">
            <strong>{{ row.label }}:</strong> {{ row.value }}
          </li>
        </ul>
      </div>

      <div v-if="projection.extraRows.length" class="detail-section">
        <h3>Ek Bilgiler</h3>
        <ul class="attributes-list">
          <li v-for="row in projection.extraRows" :key="row.key">
            <strong>{{ row.label }}:</strong> {{ row.value }}
          </li>
        </ul>
      </div>

      <div v-if="listing.supports_packages" class="detail-section">
        <h3>Paketler (Offers)</h3>
        <p class="muted">
          Bu bolum sadece tiklayinca yuklenir (sistemi zorlamaz).
        </p>
        <div class="offers-actions">
          <button
            type="button"
            class="action-button"
            :disabled="offersLoading || offersLoaded"
            @click="loadOffers"
          >
            <template v-if="offersLoaded">Paketler yuklendi</template>
            <template v-else-if="offersLoading">Yukleniyor...</template>
            <template v-else>Paketleri Goster</template>
          </button>
        </div>
        <div v-if="offersError" class="error">{{ offersError }}</div>
        <div v-else-if="offersLoaded">
          <p v-if="!offers || offers.length === 0">Bu ilan icin paket yok</p>
          <ul v-else class="offers-list">
            <li v-for="o in offers" :key="o.id" class="offer-item">
              <div class="offer-title">
                <strong>{{ o.name }}</strong>
                <span class="muted">({{ o.code }})</span>
              </div>
              <div class="muted">
                {{ o.price_amount }} {{ o.price_currency }} - {{ o.billing_model }}
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

      <div v-if="projection.technicalRows.length" class="detail-section">
        <h3>Teknik Bilgiler</h3>
        <ul class="attributes-list">
          <li v-for="row in projection.technicalRows" :key="row.key">
            <strong>{{ row.label }}:</strong> {{ row.value }}
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client';
import { getCategoriesTree, getFilterSchemaForCategory, getIntentSchemaForCategory } from '../lib/catalogSpine';
import { resolveListingActions } from '../lib/listingActions';
import { findCategoryByCanonicalId } from '../lib/categoryTree';
import { buildListingDetailProjection } from '../lib/listingDetailProjection';
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
    resolvedActions() {
      if (!this.listing) return [];
      return resolveListingActions(this.listing, { context: 'detail' });
    },
  },
  data() {
    return {
      listing: null,
      projection: null,
      loading: true,
      error: null,
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
    async loadListing() {
      try {
        this.listing = await api.getListing(this.id);
        const listing = this.listing;
        if (listing?.category_id) {
          try {
            const [tree, filterSchema, intentSchema] = await Promise.all([
              getCategoriesTree(),
              getFilterSchemaForCategory(listing.category_id),
              getIntentSchemaForCategory(listing.category_id),
            ]);
            const nodes = Array.isArray(tree) ? tree : (tree?.items ?? []);
            const categoryNode = findCategoryByCanonicalId(nodes, listing.category_id);
            this.projection = buildListingDetailProjection({
              listing,
              categoryNode,
              filterSchema,
              intentSchema,
            });
          } catch {
            this.projection = buildListingDetailProjection({
              listing,
              categoryNode: null,
              filterSchema: null,
              intentSchema: null,
            });
          }
        } else {
          this.projection = buildListingDetailProjection({
            listing,
            categoryNode: null,
            filterSchema: null,
            intentSchema: null,
          });
        }
        this.loading = false;
      } catch (err) {
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
        this.offersLoaded = true;
      } finally {
        this.offersLoading = false;
      }
    },
    handlePublished(updatedListing) {
      this.listing = updatedListing;
      if (this.projection) {
        this.projection.hero.status = updatedListing?.status || this.projection.hero.status;
      }
    },
    runAction(action) {
      if (!action || !action.to) return;
      this.$router.push(action.to);
    },
    formatPrice(amount, currency) {
      if (!amount && amount !== 0) return '';
      const c = currency || 'TRY';
      try {
        return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: c, minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(amount);
      } catch {
        return `${amount} ${c}`;
      }
    },
    modeLabel(mode) {
      const labels = { sale: 'Satilik', rental: 'Kiralik', reservation: 'Rezervasyon' };
      return labels[mode] || mode;
    },
  },
};
</script>

<style scoped>
.listing-detail-page {
  max-width: 900px;
}

.listing-detail h2 {
  margin-bottom: 0.35rem;
  font-size: 2rem;
}

.context-line {
  margin-bottom: 0.75rem;
  color: #475569;
  font-size: 1rem;
  font-weight: 600;
}

.price-banner {
  font-size: 1.75rem;
  font-weight: 700;
  color: #ef4444;
  margin-bottom: 1rem;
}

.detail-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
}

.meta-tag {
  display: inline-block;
  padding: 0.3rem 0.7rem;
  border-radius: 4px;
  font-size: 0.85rem;
  font-weight: 500;
  background: #f1f5f9;
  color: #334155;
}

.meta-status-published { background: #dcfce7; color: #166534; }
.meta-status-draft { background: #fef3c7; color: #92400e; }

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
