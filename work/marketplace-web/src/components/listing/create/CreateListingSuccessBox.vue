<template>
  <div class="success">
    <strong>Success!</strong> Listing created with ID: {{ success.id }}
    <button @click="$emit('copy-id', success.id)" class="copy-id-btn" title="Copy listing ID">Copy ID</button>
    <br />
    Status: {{ success.status }}
    <br />
    <div class="success-actions">
      <router-link :to="`/listing/${success.id}`" class="action-link">View Listing</router-link>
      <button
        v-if="success.status === 'draft'"
        @click="$emit('publish')"
        :disabled="publishing"
        class="action-button publish-button"
      >
        {{ publishing ? 'Publishing...' : 'Publish now' }}
      </button>
      <button
        v-if="success.status === 'published' && success.category_id"
        @click="$emit('go-search', success.category_id)"
        class="action-button"
      >
        Go to Search
      </button>
    </div>
    <div v-if="publishError" class="publish-error">
      <strong>Publish Error:</strong> {{ publishError.message }}
    </div>
  </div>
</template>

<script>
export default {
  name: 'CreateListingSuccessBox',
  props: {
    success: { type: Object, required: true },
    publishing: { type: Boolean, default: false },
    publishError: { type: Object, default: null },
  },
  emits: ['copy-id', 'publish', 'go-search'],
};
</script>

<style scoped>
.success {
  background: #e8f5e9;
  color: #2e7d32;
  padding: 1rem;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.success-actions {
  margin-top: 1rem;
  display: flex;
  gap: 1rem;
  align-items: center;
}

.action-link {
  color: #0066cc;
  text-decoration: underline;
}

.action-button {
  padding: 0.5rem 1rem;
  border: 1px solid #28a745;
  border-radius: 4px;
  background: #28a745;
  color: white;
  cursor: pointer;
  font-size: 0.9rem;
}

.action-button:hover {
  background: #218838;
}

.copy-id-btn {
  font-size: 0.75rem;
  padding: 0.2rem 0.5rem;
  border: 1px solid #2e7d32;
  border-radius: 3px;
  background: #2e7d32;
  color: white;
  cursor: pointer;
  margin-left: 0.5rem;
}

.copy-id-btn:hover {
  background: #1b5e20;
}

.publish-button {
  background: #4caf50;
  border-color: #4caf50;
}

.publish-button:hover:not(:disabled) {
  background: #45a049;
  border-color: #45a049;
}

.publish-button:disabled {
  background: #ccc;
  border-color: #ccc;
  cursor: not-allowed;
}

.publish-error {
  margin-top: 0.5rem;
  padding: 0.5rem;
  background: #ffebee;
  color: #d32f2f;
  border-radius: 4px;
  font-size: 0.9rem;
}
</style>
