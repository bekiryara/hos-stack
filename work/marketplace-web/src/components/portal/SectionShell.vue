<template>
  <div class="section-shell">
    <h3 class="section-title">{{ title }}</h3>
    <div v-if="status === 'loading'" class="section-loading">Yükleniyor …</div>
    <div v-else-if="status === 'error'" class="error-box">
      <div class="error-details">
        <div><strong>Message:</strong> {{ errorMessage || 'Unknown error' }}</div>
        <button type="button" class="btn-retry" @click="$emit('retry')">Yeniden dene</button>
      </div>
    </div>
    <div v-else-if="empty" class="empty-state">{{ emptyText }}</div>
    <slot v-else />
  </div>
</template>

<script>
export default {
  name: 'SectionShell',
  props: {
    title: { type: String, required: true },
    status: { type: String, required: true }, // "loading" | "error" | "ready"
    errorMessage: { type: String, default: '' },
    empty: { type: Boolean, default: false },
    emptyText: { type: String, default: 'Henüz veri yok' },
  },
  emits: ['retry'],
};
</script>

<style scoped>
.section-shell {
  margin: 2rem 0;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
  border: 1px solid #ddd;
}

.section-title {
  margin-top: 0;
  margin-bottom: 1rem;
  color: #333;
}

.section-loading {
  padding: 1rem;
  color: #666;
}

.error-box {
  padding: 1rem;
  background: #ffebee;
  border-radius: 4px;
  border: 1px solid #d32f2f;
}

.error-details {
  color: #c62828;
}

.error-details div {
  margin: 0.5rem 0;
}

.btn-retry {
  margin-top: 0.5rem;
  padding: 0.5rem 1rem;
  background: #0066cc;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
}

.btn-retry:hover {
  background: #0052a3;
}

.empty-state {
  padding: 2rem;
  text-align: center;
  color: #999;
  font-style: italic;
}
</style>
