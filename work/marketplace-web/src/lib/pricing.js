export const LEGACY_PRICE_ATTRIBUTE_KEYS = new Set([
  'vehicle_price',
  'real_estate_price',
  'product_price',
  'rent_price',
  'event_price',
  'vehicle_price_per_day',
]);

export function isLegacyPriceAttributeKey(key) {
  return LEGACY_PRICE_ATTRIBUTE_KEYS.has(String(key || ''));
}
