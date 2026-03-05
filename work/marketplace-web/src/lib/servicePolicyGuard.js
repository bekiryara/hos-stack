function safeObject(v) {
  return v && typeof v === 'object' && !Array.isArray(v) ? v : {};
}

function normalizeText(v) {
  return String(v || '').trim();
}

export function modeGuardReasonForListing(listing, mode) {
  const attrs = safeObject(listing?.attributes);
  const timeModel = normalizeText(attrs.service_time_model);
  const offerRule = normalizeText(attrs.offer_requirement);
  const txMode = normalizeText(mode);

  if (!txMode) return null;
  if (!timeModel) return null;

  if (txMode === 'reservation' && !['slot', 'session'].includes(timeModel)) {
    return 'Bu ilanda rezervasyon icin zaman modeli uyumsuz.';
  }
  if (txMode === 'rental' && !['none', 'date_range'].includes(timeModel)) {
    return 'Bu ilanda kiralama icin zaman modeli uyumsuz.';
  }
  if (txMode === 'sale' && timeModel !== 'none') {
    return 'Bu ilanda satin alma akisi zaman modeli ile uyumsuz.';
  }
  if ((txMode === 'rental' || txMode === 'sale') && offerRule === 'required_offer') {
    return 'Bu ilanda paket zorunlulugu nedeniyle bu akis desteklenmiyor.';
  }

  return null;
}

export function isModeAllowedForListing(listing, mode) {
  return !modeGuardReasonForListing(listing, mode);
}
