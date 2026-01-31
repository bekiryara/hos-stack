<template>
  <RecordsPanelBase
    ref="baseRef"
    scope="firm"
    kind="rentals"
    :active-tenant-id="activeTenantId"
  />
</template>

<script>
import RecordsPanelBase from '../../common/RecordsPanelBase.vue';

export default {
  name: 'FirmRentalsPanel',
  components: { RecordsPanelBase },
  props: {
    activeTenantId: { type: String, required: true },
  },
  methods: {
    load() {
      return this.$refs.baseRef?.load?.() ?? Promise.resolve();
    },
  },
};
</script>
