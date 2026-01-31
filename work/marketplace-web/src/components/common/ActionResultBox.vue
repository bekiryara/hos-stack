<template>
  <div
    v-if="showBox"
    :class="['action-result-box', boxClass]"
    :role="role"
    :aria-live="role === 'alert' ? 'assertive' : 'polite'"
  >
    <div v-if="loading" class="arb-loading">Loading …</div>
    <template v-else-if="error">
      <p class="arb-message">{{ error }}</p>
      <div class="arb-actions">
        <button v-if="onRetry" type="button" class="arb-retry" @click="onRetry">{{ retryText }}</button>
        <slot name="extra" />
      </div>
    </template>
    <template v-else-if="success">
      <p class="arb-message">{{ success }}</p>
      <slot name="extra" />
    </template>
    <template v-else-if="empty && showWhenEmpty">
      <p class="arb-message arb-empty">{{ emptyText }}</p>
      <div class="arb-actions">
        <button v-if="onRetry" type="button" class="arb-retry" @click="onRetry">{{ retryText }}</button>
        <slot name="extra" />
      </div>
    </template>
  </div>
</template>

<script>
export default {
  name: 'ActionResultBox',
  props: {
    loading: { type: Boolean, default: false },
    error: { type: String, default: null },
    success: { type: String, default: null },
    empty: { type: Boolean, default: false },
    emptyText: { type: String, default: 'No data' },
    retryText: { type: String, default: 'Retry' },
    onRetry: { type: Function, default: null },
    showWhenEmpty: { type: Boolean, default: true },
  },
  computed: {
    showBox() {
      return this.loading || this.error || this.success || (this.empty && this.showWhenEmpty);
    },
    boxClass() {
      if (this.loading) return 'arb-loading-state';
      if (this.error) return 'arb-error';
      if (this.success) return 'arb-success';
      if (this.empty && this.showWhenEmpty) return 'arb-empty-state';
      return '';
    },
    role() {
      if (this.error) return 'alert';
      return 'status';
    },
  },
};
</script>

<style scoped>
.action-result-box {
  padding: 1rem;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.arb-loading,
.arb-message {
  margin: 0 0 0.75rem 0;
}

.arb-message:last-child,
.arb-loading:last-child {
  margin-bottom: 0;
}

.arb-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
}

.arb-retry {
  padding: 0.4rem 0.8rem;
  background: #d32f2f;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.875rem;
}

.arb-retry:hover {
  background: #b71c1c;
}

.arb-loading-state {
  background: #f5f5f5;
  border: 1px solid #ddd;
  color: #666;
}

.arb-error {
  background: #ffebee;
  border: 1px solid #d32f2f;
  color: #c62828;
}

.arb-success {
  background: #e8f5e9;
  border: 1px solid #2e7d32;
  color: #1b5e20;
}

.arb-empty-state .arb-message.arb-empty {
  font-style: italic;
  color: #999;
}

.arb-empty-state {
  background: #fafafa;
  border: 1px solid #eee;
  color: #666;
}
</style>
