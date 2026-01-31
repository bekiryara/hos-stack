<template>
  <div
    v-if="show"
    class="limited-view-banner"
    role="status"
    aria-live="polite"
  >
    {{ limitedMessage(reason) }}
    <span v-if="errorText" class="limited-view-api-error">API: {{ errorText }}</span>
  </div>
</template>

<script>
import { limitedMessage as getLimitedMessage } from '../../lib/detail/limited_view.js';

export default {
  name: 'LimitedViewBanner',
  props: {
    show: { type: Boolean, default: false },
    reason: { type: String, default: 'unknown' },
    errorText: { type: String, default: null },
  },
  methods: {
    limitedMessage(reason) {
      return getLimitedMessage(reason);
    },
  },
};
</script>

<style scoped>
.limited-view-banner {
  padding: 0.5rem 1rem;
  background: #fff3cd;
  border: 1px solid #ffc107;
  border-radius: 4px;
  margin-bottom: 1rem;
  font-size: 0.9rem;
}

.limited-view-api-error {
  display: block;
  margin-top: 0.35rem;
  font-size: 0.85rem;
  color: #666;
}
</style>
