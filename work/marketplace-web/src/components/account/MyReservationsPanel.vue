<template>
  <RecordsPanelBase
    ref="baseRef"
    scope="customer"
    kind="reservations"
    :active="active"
  />
</template>

<script>
import RecordsPanelBase from '../common/RecordsPanelBase.vue';

export default {
  name: 'AccountMyReservationsPanel',
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
