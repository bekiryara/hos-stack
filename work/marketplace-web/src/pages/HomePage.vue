<template>
  <div class="home-page">
    <div class="layout">
      <aside class="sidebar">
        <div class="sidebar-card">
          <div class="sidebar-title">Keşfet</div>
          <div class="subtitle">Kategorilerden gez, aramaya hızlı geç.</div>

          <div class="search-row">
            <input
              v-model="q"
              type="text"
              class="search-input"
              placeholder="Kategori ara (örn: otomobil, emlak, konut)"
            />
            <router-link class="search-link" to="/search">Ara</router-link>
          </div>
        </div>

        <div class="sidebar-card">
          <div class="sidebar-title">Kökler</div>
          <div v-if="loading" class="loading">Yükleniyor...</div>
          <div v-else-if="error" class="error">{{ error }}</div>
          <div v-else class="root-list">
            <button
              v-for="root in roots"
              :key="root.id"
              type="button"
              class="root-btn"
              :class="{ active: String(root.id) === String(selectedRootId) }"
              @click="selectRoot(root.id)"
            >
              {{ labelFor(root) }}
            </button>
          </div>
        </div>

        <router-link to="/categories" class="all-categories-link">
          Tüm kategoriler (ağaç)
        </router-link>
      </aside>

      <main class="main">
        <div v-if="loading" class="loading">Kategoriler yükleniyor...</div>
        <div v-else-if="error" class="error">{{ error }}</div>

        <div v-else-if="filteredRoots.length === 0" class="empty-state">
          Sonuç bulunamadı.
        </div>

        <!-- Arama varsa: root kartları -->
        <div v-else-if="normalizedQuery" class="roots">
          <section
            v-for="root in filteredRoots"
            :key="root.id"
            class="root-card"
          >
            <div class="root-header">
              <div class="root-title">
                {{ labelFor(root) }}
              </div>
              <router-link v-if="canonicalIdFor(root)" class="root-all" :to="`/search/${canonicalIdFor(root)}`">
                Tümünü gör
              </router-link>
              <span v-else class="root-all" aria-disabled="true">Tümünü gör</span>
            </div>

            <div class="root-children">
              <router-link
                v-for="child in (root.children || [])"
                :key="child.id"
                v-if="canonicalIdFor(child)"
                class="child-pill"
                :to="`/search/${canonicalIdFor(child)}`"
              >
                {{ labelFor(child) }}
              </router-link>
              <span
                v-for="child in (root.children || [])"
                :key="`no-link-${child.id}`"
                v-else
                class="child-pill"
                aria-disabled="true"
              >
                {{ labelFor(child) }}
              </span>
            </div>
          </section>
        </div>

        <!-- Arama yoksa: seçili kökün ana dalları -->
        <div v-else class="selected">
          <div class="selected-header">
            <h2 class="selected-title">{{ labelFor(selectedRoot) }}</h2>
            <router-link v-if="canonicalIdFor(selectedRoot)" class="root-all" :to="`/search/${canonicalIdFor(selectedRoot)}`">
              Tümünü gör
            </router-link>
            <span v-else class="root-all" aria-disabled="true">Tümünü gör</span>
          </div>

          <div class="root-children">
            <router-link
              v-for="child in (selectedRoot.children || [])"
              :key="child.id"
              v-if="canonicalIdFor(child)"
              class="child-pill"
              :to="`/search/${canonicalIdFor(child)}`"
            >
              {{ labelFor(child) }}
            </router-link>
            <span
              v-for="child in (selectedRoot.children || [])"
              :key="`no-link-selected-${child.id}`"
              v-else
              class="child-pill"
              aria-disabled="true"
            >
              {{ labelFor(child) }}
            </span>
          </div>
        </div>
      </main>
    </div>
  </div>
</template>

<script>
import { getCategoriesTree } from '../lib/catalogSpine';
import { categoryLabel } from '../lib/categoryTree';

export default {
  name: 'HomePage',
  data() {
    return {
      categories: [],
      loading: true,
      error: null,
      q: '',
      selectedRootId: null,
    };
  },
  computed: {
    roots() {
      return Array.isArray(this.categories) ? this.categories : [];
    },
    selectedRoot() {
      const roots = this.roots;
      if (!roots.length) return { id: null, children: [] };
      const wanted = this.selectedRootId ? String(this.selectedRootId) : null;
      const found = wanted ? roots.find((r) => String(r.id) === wanted) : null;
      return found || roots[0];
    },
    normalizedQuery() {
      return String(this.q || '').toLowerCase().trim();
    },
    filteredRoots() {
      const q = this.normalizedQuery;
      if (!q) return this.roots;

      // Root title matches OR any direct child matches.
      return this.roots
        .map((r) => {
          const children = Array.isArray(r.children) ? r.children : [];
          const rootLabel = this.labelFor(r).toLowerCase();
          const matchedChildren = children.filter((c) =>
            this.labelFor(c).toLowerCase().includes(q)
          );
          const rootMatches = rootLabel.includes(q);
          if (!rootMatches && matchedChildren.length === 0) return null;
          if (rootMatches) return r;
          return { ...r, children: matchedChildren };
        })
        .filter(Boolean);
    },
  },
  async mounted() {
    try {
      this.categories = await getCategoriesTree({ view: 'menu' });
      if (!this.selectedRootId && Array.isArray(this.categories) && this.categories[0]) {
        this.selectedRootId = this.categories[0].id;
      }
      this.loading = false;
    } catch (err) {
      this.error = err && err.message ? err.message : 'Kategoriler yüklenemedi';
      this.loading = false;
    }
  },
  methods: {
    labelFor(node) {
      return categoryLabel(node);
    },
    canonicalIdFor(node) {
      if (!node) return null;
      const cid = node.canonical_category_id !== undefined && node.canonical_category_id !== null
        ? Number(node.canonical_category_id)
        : null;
      if (Number.isFinite(cid) && cid > 0) return cid;
      const id = node.id !== undefined && node.id !== null ? Number(node.id) : null;
      if (Number.isFinite(id) && id > 0) return id;
      return null;
    },
    selectRoot(id) {
      this.selectedRootId = id;
    },
  },
};
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: 360px 1fr;
  gap: 1rem;
  align-items: start;
}

.sidebar {
  position: sticky;
  top: 1rem;
  max-height: calc(100vh - 140px);
  overflow: auto;
  padding-right: 0.25rem;
}

.sidebar-card {
  margin-bottom: 0.9rem;
  padding: 0.9rem;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  background: #fff;
}

.sidebar-title {
  font-weight: 800;
  margin-bottom: 0.35rem;
}

.subtitle {
  color: #666;
  font-size: 0.95rem;
}

.search-row {
  margin-top: 0.75rem;
  display: flex;
  gap: 0.6rem;
  align-items: center;
}

.search-input {
  flex: 1;
  padding: 0.7rem 0.85rem;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 1rem;
}

.search-link {
  padding: 0.7rem 0.95rem;
  border-radius: 8px;
  background: #0066cc;
  color: #fff;
  text-decoration: none;
  white-space: nowrap;
}

.search-link:hover {
  background: #0056ad;
}

.root-list {
  display: grid;
  grid-template-columns: 1fr;
  gap: 0.35rem;
  margin-top: 0.5rem;
}

.root-btn {
  text-align: left;
  border: 1px solid #e5e7eb;
  background: #f9fafb;
  padding: 0.5rem 0.65rem;
  border-radius: 8px;
  cursor: pointer;
}

.root-btn:hover {
  background: #f3f4f6;
}

.root-btn.active {
  background: #e8f1ff;
  border-color: #b6d1ff;
}

.all-categories-link {
  display: inline-block;
  color: #0066cc;
  text-decoration: none;
  margin-top: 0.25rem;
}

.all-categories-link:hover {
  text-decoration: underline;
}

.main {
  min-height: 420px;
}

.selected-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.selected-title {
  margin: 0;
  font-size: 1.8rem;
}

.roots {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
}

.root-card {
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 1rem;
  background: #fff;
}

.root-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.root-title {
  font-weight: 800;
  font-size: 1.05rem;
}

.root-all {
  font-size: 0.9rem;
  text-decoration: none;
  color: #0066cc;
}

.root-all:hover {
  text-decoration: underline;
}

.root-children {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.child-pill {
  display: inline-block;
  padding: 0.45rem 0.65rem;
  border-radius: 999px;
  border: 1px solid #e5e7eb;
  background: #f9fafb;
  color: #111;
  text-decoration: none;
  font-size: 0.95rem;
}

.child-pill:hover {
  background: #f3f4f6;
}

.empty-state {
  padding: 1rem;
  border: 1px dashed #ddd;
  border-radius: 10px;
  color: #666;
}

@media (max-width: 980px) {
  .layout {
    grid-template-columns: 1fr;
  }
  .sidebar {
    position: static;
    max-height: none;
    overflow: visible;
    padding-right: 0;
  }
  .roots {
    grid-template-columns: 1fr;
  }
}
</style>

