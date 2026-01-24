<template>
  <div class="demo-dashboard-page" data-test="demo-dashboard" data-marker="marketplace-demo">
    <div class="header">
      <h2>Demo Dashboard</h2>
      <button @click="exitDemo" class="exit-demo-button" data-marker="exit-demo">Exit Demo</button>
    </div>
    <div class="tenant-section">
      <!-- Always visible tenant section -->
      <div class="tenant-info">
        <template v-if="activeTenantId">
          <strong>Active Tenant ID:</strong>
          <code class="tenant-id">{{ activeTenantId }}</code>
          <button @click="copyTenantId" class="copy-button" title="Copy to clipboard">Copy</button>
          <button @click="showMembershipSelector = !showMembershipSelector" class="change-tenant-button">
            {{ showMembershipSelector ? 'Cancel' : 'Change Tenant' }}
          </button>
        </template>
        <template v-else>
          <strong>No Active Tenant</strong>
          <button @click="loadMemberships" class="load-memberships-button" :disabled="loadingMemberships">
            {{ loadingMemberships ? 'Loading...' : 'Load Memberships' }}
          </button>
        </template>
      </div>
      
      <!-- WP-62: Tenant selector -->
      <div v-if="showMembershipSelector && memberships" class="membership-selector">
        <h4>Select Active Tenant:</h4>
        <div v-for="membership in memberships" :key="membership.tenant_id || membership.tenant?.id" class="membership-item">
          <button @click="setActiveTenant(membership)" class="tenant-select-button">
            <strong>{{ membership.tenant?.name || membership.tenant_id || 'Unknown' }}</strong>
            <span class="tenant-id-small">{{ membership.tenant_id || membership.tenant?.id }}</span>
            <span v-if="membership.role" class="role-badge">{{ membership.role }}</span>
          </button>
        </div>
      </div>
    </div>
    <div v-if="loading" class="loading">Loading demo listing...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    <div v-else-if="listing" class="demo-listing">
      <h3>{{ listing.title || 'Demo Listing' }}</h3>
      <p><strong>Status:</strong> {{ listing.status }}</p>
      <p v-if="listing.description">{{ listing.description }}</p>
      <div class="actions">
        <button @click="openMessaging" class="action-button">Message Seller</button>
        <router-link :to="`/listing/${listing.id}`" class="action-button">View Details</router-link>
      </div>
    </div>
  </div>
</template>

<script>
import { api } from '../api/client';
import { clearToken, enterDemoUrl, getToken } from '../lib/demoSession.js';

export default {
  name: 'DemoDashboardPage',
  data() {
    return {
      listing: null,
      loading: true,
      error: null,
      activeTenantId: null,
      memberships: null, // WP-62: Store memberships for tenant selection
      loadingMemberships: false, // WP-62: Track loading state
      showMembershipSelector: false, // WP-62: Show/hide tenant selector
    };
  },
  async mounted() {
    await this.loadActiveTenantId();
    await this.ensureDemoListing();
  },
  methods: {
    exitDemo() {
      clearToken();
      window.location.href = enterDemoUrl;
    },
    async loadActiveTenantId() {
      // WP-62: Use client.js helper (single source of truth)
      const storedTenantId = api.getActiveTenantId();
      if (storedTenantId) {
        this.activeTenantId = storedTenantId;
        return;
      }
      
      // Auto-load from memberships if demo token exists
      const demoToken = getToken();
      if (demoToken) {
        await this.loadMemberships(true); // Auto-select first/admin
      }
    },
    async loadMemberships(autoSelect = false) {
      // WP-62: Load memberships and optionally auto-select tenant
      const demoToken = getToken();
      if (!demoToken) {
        this.error = 'No demo token found. Please enter demo first.';
        return;
      }
      
      this.loadingMemberships = true;
      try {
        const membershipsResponse = await api.getMyMemberships(demoToken);
        const items = membershipsResponse.items || membershipsResponse.data || (Array.isArray(membershipsResponse) ? membershipsResponse : []);
        this.memberships = items;
        
        if (autoSelect && items.length > 0) {
          // Prefer admin role, else first membership
          const adminMembership = items.find(m => m.role === 'admin' || m.role === 'owner');
          const selectedMembership = adminMembership || items[0];
          const tenantId = selectedMembership.tenant_id || selectedMembership.tenant?.id;
          if (tenantId) {
            this.setActiveTenant(selectedMembership);
          }
        } else if (items.length > 0) {
          // Show selector if not auto-selecting
          this.showMembershipSelector = true;
        }
      } catch (err) {
        console.error('Could not fetch memberships:', err);
        this.error = 'Failed to load memberships. Please try again.';
      } finally {
        this.loadingMemberships = false;
      }
    },
    setActiveTenant(membership) {
      // WP-62: Set active tenant using client.js helper
      const tenantId = membership.tenant_id || membership.tenant?.id;
      if (tenantId) {
        api.setActiveTenantId(tenantId);
        this.activeTenantId = tenantId;
        this.showMembershipSelector = false;
      }
    },
    copyTenantId() {
      if (this.activeTenantId) {
        navigator.clipboard.writeText(this.activeTenantId).then(() => {
          // Visual feedback could be added here
          alert('Tenant ID copied to clipboard!');
        }).catch(err => {
          console.error('Failed to copy:', err);
        });
      }
    },
    async ensureDemoListing() {
      try {
        // Try to get existing published listings
        const listings = await api.searchListings({ status: 'published', limit: 1 });
        const items = Array.isArray(listings) ? listings : (listings.items || []);
        
        if (items.length > 0) {
          this.listing = items[0];
          this.loading = false;
          return;
        }

        // If no published listing exists, try to get any listing
        const allListings = await api.searchListings({ limit: 1 });
        const allItems = Array.isArray(allListings) ? allListings : (allListings.items || []);
        
        if (allItems.length > 0) {
          this.listing = allItems[0];
          this.loading = false;
          return;
        }

        // No listing found - show message
        this.error = 'No demo listing found. Please create a listing first.';
        this.loading = false;
      } catch (err) {
        this.error = err.message;
        this.loading = false;
      }
    },
    openMessaging() {
      if (this.listing && this.listing.id) {
        this.$router.push(`/listing/${this.listing.id}/message`);
      }
    },
  },
};
</script>

<style scoped>
.demo-dashboard-page {
  max-width: 900px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.demo-dashboard-page h2 {
  margin: 0;
  font-size: 2rem;
}

.exit-demo-button {
  padding: 0.5rem 1rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  background: #f5f5f5;
  color: #333;
  cursor: pointer;
  font-size: 0.9rem;
}

.exit-demo-button:hover {
  background: #e5e5e5;
}

.demo-listing {
  padding: 1.5rem;
  background: #f9f9f9;
  border-radius: 8px;
  margin-top: 1rem;
}

.demo-listing h3 {
  margin-bottom: 1rem;
  font-size: 1.5rem;
}

.actions {
  margin-top: 1.5rem;
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
}

.action-button:hover {
  background: #0052a3;
}

.tenant-section {
  margin-bottom: 1rem;
  display: block; /* Ensure it's visible */
  min-height: 50px; /* Ensure it takes space even if empty */
}

.tenant-info {
  padding: 1rem;
  background: #e3f2fd;
  border-radius: 4px;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.tenant-id {
  font-family: monospace;
  background: white;
  padding: 0.25rem 0.5rem;
  border-radius: 3px;
  font-size: 0.9rem;
}

.copy-button {
  padding: 0.25rem 0.75rem;
  border: 1px solid #1976d2;
  border-radius: 3px;
  background: #1976d2;
  color: white;
  cursor: pointer;
  font-size: 0.85rem;
}

.copy-button:hover {
  background: #1565c0;
}
</style>

