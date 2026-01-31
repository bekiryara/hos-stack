<template>
  <div class="toast-host" aria-label="Notifications">
    <div
      v-for="toast in toasts"
      :key="toast.id"
      :class="['toast', `toast-${toast.type}`]"
      :role="toast.type === 'error' ? 'alert' : 'status'"
      :aria-live="toast.type === 'error' ? 'assertive' : 'polite'"
    >
      <span class="toast-message">{{ toast.message }}</span>
      <button
        type="button"
        class="toast-close"
        aria-label="Close"
        @click="remove(toast.id)"
      >
        ×
      </button>
    </div>
  </div>
</template>

<script>
import { getToasts, removeToast, subscribe } from '../lib/toast/toast_store.js';

export default {
  name: 'ToastHost',
  data() {
    return {
      toasts: [],
    };
  },
  mounted() {
    this.refresh();
    this.unsub = subscribe(() => this.refresh());
    this.timeouts = new Map();
    this.scheduleDismiss();
  },
  beforeUnmount() {
    if (this.unsub) this.unsub();
    this.timeouts.forEach((id) => clearTimeout(id));
    this.timeouts.clear();
  },
  methods: {
    refresh() {
      this.toasts = getToasts();
      this.scheduleDismiss();
    },
    remove(id) {
      const t = this.timeouts.get(id);
      if (t) {
        clearTimeout(t);
        this.timeouts.delete(id);
      }
      removeToast(id);
    },
    scheduleDismiss() {
      const now = Date.now();
      this.toasts.forEach((t) => {
        if (this.timeouts.has(t.id)) return;
        const elapsed = now - t.created_at;
        const remaining = Math.max(0, (t.timeout_ms || 3500) - elapsed);
        const timeoutId = setTimeout(() => {
          this.timeouts.delete(t.id);
          removeToast(t.id);
        }, remaining);
        this.timeouts.set(t.id, timeoutId);
      });
    },
  },
};
</script>

<style scoped>
.toast-host {
  position: fixed;
  top: 1rem;
  right: 1rem;
  z-index: 9999;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  max-width: 360px;
}

.toast {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-radius: 4px;
  border: 1px solid transparent;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  background: #fff;
}

.toast-message {
  flex: 1;
  font-size: 0.9rem;
  line-height: 1.4;
}

.toast-close {
  flex-shrink: 0;
  width: 1.5rem;
  height: 1.5rem;
  padding: 0;
  border: none;
  background: transparent;
  font-size: 1.25rem;
  line-height: 1;
  cursor: pointer;
  color: #666;
}

.toast-close:hover {
  color: #333;
}

.toast-success {
  background: #d4edda;
  border-color: #c3e6cb;
  color: #155724;
}

.toast-error {
  background: #f8d7da;
  border-color: #f5c6cb;
  color: #721c24;
}

.toast-info {
  background: #d1ecf1;
  border-color: #bee5eb;
  color: #0c5460;
}
</style>
