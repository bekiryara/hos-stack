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
      <div v-if="listing" class="detail-section">
        <h3>Full Data</h3>
        <pre class="full-json">{{ JSON.stringify(listing, null, 2) }}</pre>
      </div>
      <div class="actions">
        <button @click="openMessaging" class="action-button">Message Seller</button>
      </div>
      <TransactionActionBar v-if="listing" :listing="listing" />
      
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
import PublishListingAction from '../components/PublishListingAction.vue';
import TransactionActionBar from '../components/listing/TransactionActionBar.vue';

function findCategoryInTree(nodes, categoryId) {
  if (!Array.isArray(nodes)) return null;
  const id = String(categoryId);
  for (const node of nodes) {
    if (String(node.id) === id) return node;
    if (node.children?.length) {
      const found = findCategoryInTree(node.children, categoryId);
      if (found) return found;
    }
  }
  return null;
}

export default {
  name: 'ListingDetailPage',
  components: {
    PublishListingAction,
    TransactionActionBar,
  },
  props: {
    id: {
      type: String,
      required: true,
    },
  },
  computed: {
    listingId() {
      return String(this.listing?.id ?? this.$route.params.id ?? '');
    },
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
  },
  data() {
    return {
      listing: null,
      loading: true,
      error: null,
      categoryName: null,
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
            const found = findCategoryInTree(nodes, this.listing.category_id);
            this.categoryName = found ? (found.name || found.slug || found.title || String(found.id)) : null;
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
    handlePublished(updatedListing) {
      this.listing = updatedListing;
    },
    openMessaging() {
      const query = { as: 'customer' };
      if (this.listing?.tenant_id) {
        query.tenant_id = this.listing.tenant_id;
      }
      this.$router.push({ path: `/listing/${this.id}/message`, query });
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

