<template>
  <div class="pricing-summary">
    <div class="pricing-row">
      <span class="pricing-label">{{ unitLabel }}</span>
      <span class="pricing-value">{{ formatMoney(resolvedUnitPrice, resolvedCurrency) }}</span>
    </div>
    <div class="pricing-row">
      <span class="pricing-label">{{ resolvedMultiplierLabel }}</span>
      <span class="pricing-value">{{ resolvedMultiplier }}</span>
    </div>
    <div class="pricing-row pricing-row-final">
      <span class="pricing-label">Toplam</span>
      <span class="pricing-value">{{ formatMoney(resolvedSubtotal, resolvedCurrency) }}</span>
    </div>
  </div>
</template>

<script>
import { formatDisplayPrice } from '../../lib/displayFormatters.js';

export default {
  name: 'PricingSummary',
  props: {
    totals: { type: Object, default: null },
    priceAmount: { type: [Number, String], default: null },
    priceCurrency: { type: String, default: 'TRY' },
    multiplier: { type: [Number, String], default: 1 },
    billingModel: { type: String, default: '' },
    unitLabel: { type: String, default: 'Birim Fiyat' },
    multiplierLabel: { type: String, default: '' },
  },
  computed: {
    resolvedCurrency() {
      return this.totals?.currency || this.priceCurrency || 'TRY';
    },
    resolvedUnitPrice() {
      if (this.totals?.unit_price != null) return this.totals.unit_price;
      return this.priceAmount;
    },
    resolvedSubtotal() {
      if (this.totals?.subtotal != null) return this.totals.subtotal;
      const base = Number(this.priceAmount);
      const mult = Number(this.multiplier);
      if (!Number.isFinite(base) || !Number.isFinite(mult)) return null;
      return base * mult;
    },
    resolvedMultiplier() {
      if (this.totals?.multiplier != null) return this.totals.multiplier;
      return this.multiplier ?? 1;
    },
    resolvedBillingModel() {
      const fromTotals = this.totals?.billing_model;
      if (typeof fromTotals === 'string' && fromTotals.trim() !== '') return fromTotals.trim();
      if (typeof this.billingModel === 'string' && this.billingModel.trim() !== '') return this.billingModel.trim();
      return '';
    },
    resolvedMultiplierLabel() {
      if (typeof this.multiplierLabel === 'string' && this.multiplierLabel.trim() !== '') {
        return this.multiplierLabel.trim();
      }
      const map = {
        one_time: 'Adet',
        per_day: 'Gun',
        per_night: 'Gece',
        per_month: 'Ay',
        per_person: 'Kisi',
        per_hour: 'Saat',
        per_session: 'Seans',
        per_visit: 'Ziyaret',
      };
      return map[this.resolvedBillingModel] || 'Carpan';
    },
  },
  methods: {
    formatMoney(amount, currency) {
      return formatDisplayPrice(amount, currency);
    },
  },
};
</script>

<style scoped>
.pricing-summary {
  padding: 0.9rem;
  background: #fafafa;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
}

.pricing-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.3rem 0;
}

.pricing-row-final {
  margin-top: 0.25rem;
  padding-top: 0.55rem;
  border-top: 1px solid #e5e7eb;
  font-weight: 700;
}

.pricing-label {
  color: #64748b;
  font-size: 0.9rem;
}

.pricing-value {
  color: #0f172a;
  font-size: 0.95rem;
  font-weight: 600;
}

.pricing-row-final .pricing-value {
  font-size: 1.02rem;
}
</style>
