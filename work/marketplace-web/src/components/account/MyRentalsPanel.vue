<template>
  <RecordsPanelBase
    ref="baseRef"
    scope="customer"
    kind="rentals"
    :active="active"
  />
</template>

<script>
import RecordsPanelBase from '../common/RecordsPanelBase.vue';

export default {
  name: 'AccountMyRentalsPanel',
  components: { RecordsPanelBase },
  props: {
    active: { type: Boolean, default: false },
  },
  methods: {
    load() {
      return this.$refs.baseRef?.load?.() ?? Promise.resolve();
    },
  },
};
</script>
