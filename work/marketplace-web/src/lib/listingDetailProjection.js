const POLICY_KEYS = new Set(['offer_variant', 'interaction_mode', 'gender_context']);

const CONTEXT_KEYS = new Set(['city']);

function asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function toMap(filters) {
  const out = {};
  asArray(filters).forEach((filter) => {
    if (!filter?.attribute_key) return;
    out[String(filter.attribute_key)] = filter;
  });
  return out;
}

function isContextKey(key) {
  return CONTEXT_KEYS.has(key)
    || key.endsWith('_seller_type')
    || key.endsWith('_listing_age')
    || key.endsWith('_listing_date');
}

function renderValue(value, filter = null) {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value === 'boolean') return value ? 'Evet' : 'Hayir';
  if (Array.isArray(value)) {
    const joined = value
      .map((entry) => (entry != null && typeof entry === 'object' ? JSON.stringify(entry) : String(entry)))
      .join(', ');
    return joined || null;
  }
  if (typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch {
      return '[object]';
    }
  }

  let rendered = String(value);
  if (filter?.unit === 'm2') rendered = `${rendered} m2`;
  else if (filter?.unit) rendered = `${rendered} ${filter.unit}`;
  return rendered;
}

function buildRow(key, value, filterMap) {
  const filter = filterMap[key] || null;
  const rendered = renderValue(value, filter);
  if (rendered === null) return null;
  return {
    key,
    label: filter?.label || key,
    value: rendered,
  };
}

function resolveVariantLabel(rawVariant, intentSchema) {
  if (!rawVariant) return null;
  const key = String(rawVariant);
  const variants = asArray(intentSchema?.offer_variants);
  const found = variants.find((variant) => String(variant?.key || '') === key);
  return found?.label || key;
}

function resolveInteractionLabel(mode) {
  if (!mode) return null;
  if (mode === 'flow') return 'Sistem uzerinden';
  if (mode === 'contact_only') return 'Iletisim ile';
  return String(mode);
}

function resolveModeLabel(mode) {
  if (!mode) return null;
  if (mode === 'sale') return 'Satilik';
  if (mode === 'rental') return 'Kiralik';
  if (mode === 'reservation') return 'Rezervasyon';
  return String(mode);
}

export function buildListingDetailProjection({ listing, categoryNode, filterSchema, intentSchema }) {
  const attrs = asObject(listing?.attributes);
  const filters = asArray(filterSchema?.filters);
  const filterMap = toMap(filters);

  const summaryRows = asArray(listing?.card_highlights)
    .map((item) => {
      if (!item?.key) return null;
      return buildRow(String(item.key), item.value, filterMap);
    })
    .filter(Boolean);

  const featureRows = filters
    .map((filter) => {
      const key = String(filter?.attribute_key || '');
      if (!key || POLICY_KEYS.has(key) || isContextKey(key)) return null;
      return buildRow(key, attrs[key], filterMap);
    })
    .filter(Boolean);

  const contextRows = Object.keys(attrs)
    .filter((key) => !POLICY_KEYS.has(key) && isContextKey(key))
    .sort()
    .map((key) => buildRow(key, attrs[key], filterMap))
    .filter(Boolean);

  const policyRows = [];
  const offerVariant = attrs.offer_variant || listing?.offer_variant || null;
  const interactionMode = attrs.interaction_mode || listing?.interaction_mode || null;
  const primaryTransactionMode = asArray(listing?.transaction_modes)[0] || null;
  const primaryPolicyLabel = resolveVariantLabel(offerVariant, intentSchema) || resolveModeLabel(primaryTransactionMode);
  if (offerVariant) {
    policyRows.push({
      key: 'offer_variant',
      label: 'Ilan Turu',
      value: resolveVariantLabel(offerVariant, intentSchema),
    });
  }
  if (interactionMode) {
    policyRows.push({
      key: 'interaction_mode',
      label: 'Islem Yontemi',
      value: resolveInteractionLabel(interactionMode),
    });
  }

  const extraRows = Object.keys(attrs)
    .filter((key) => !POLICY_KEYS.has(key) && !filterMap[key])
    .sort()
    .map((key) => buildRow(key, attrs[key], filterMap))
    .filter(Boolean);

  return {
    hero: {
      title: listing?.title || 'Untitled Listing',
      price: listing?.price,
      priceCurrency: listing?.price_currency,
      categoryName: categoryNode ? String(categoryNode.title || categoryNode.slug || categoryNode.id) : null,
      status: listing?.status || null,
      transactionModes: asArray(listing?.transaction_modes),
      primaryContextLine: [primaryPolicyLabel, categoryNode ? String(categoryNode.title || categoryNode.slug || categoryNode.id) : null]
        .filter(Boolean)
        .join(' / '),
    },
    summaryRows,
    description: listing?.description || '',
    featureRows,
    contextRows,
    policyRows,
    extraRows,
    technicalRows: [
      listing?.id ? { key: 'listing_id', label: 'Ilan Referansi', value: String(listing.id) } : null,
      listing?.category_id ? { key: 'category_id', label: 'Kategori Referansi', value: String(listing.category_id) } : null,
    ].filter(Boolean),
  };
}

