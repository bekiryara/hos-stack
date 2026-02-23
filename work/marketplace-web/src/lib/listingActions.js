/**
 * Listing actions resolver (single source of truth).
 *
 * CTA labels and routes are data-driven via a mode registry.
 * Adding a new transaction mode only requires adding an entry here
 * (and the corresponding backend route/spine).
 */

const MODE_CTA = {
  reservation: {
    key: 'reservation',
    labelDetail: 'Rezervasyon Yap',
    labelGrid: 'Rezerve Et',
    path: '/reservation/create',
    uiClassGrid: 'reserve-btn',
  },
  rental: {
    key: 'rental',
    labelDetail: 'Kiralama Yap',
    labelGrid: 'Kirala',
    path: '/rental/create',
    uiClassGrid: 'rent-btn',
  },
  sale: {
    key: 'sale',
    labelDetail: 'Satın Al',
    labelGrid: 'Satın Al',
    path: '/order/create',
    uiClassGrid: 'buy-btn',
  },
};

function safeArray(v) {
  return Array.isArray(v) ? v : [];
}

function safeObject(v) {
  return v && typeof v === 'object' && !Array.isArray(v) ? v : {};
}

function buildMessagingTo(listingId, tenantId) {
  const query = { as: 'customer' };
  if (tenantId) query.tenant_id = tenantId;
  return { path: `/listing/${listingId}/message`, query };
}

/**
 * @param {object} listing
 * @param {object} [opts]
 * @param {'detail'|'grid'} [opts.context]
 * @returns {Array<{key:string,label:string,to:object,uiClass?:string}>}
 */
export function resolveListingActions(listing, opts = {}) {
  const context = opts.context || 'detail';
  const listingId = listing && listing.id ? String(listing.id) : '';
  const tenantId = listing && listing.tenant_id ? String(listing.tenant_id) : '';
  const modes = safeArray(listing && listing.transaction_modes).map(String);
  const attrs = safeObject(listing && listing.attributes);
  const interactionMode = attrs.interaction_mode ? String(attrs.interaction_mode) : 'contact_only';

  const canFlow = interactionMode === 'flow';
  const msgTo = listingId ? buildMessagingTo(listingId, tenantId) : null;
  const actions = [];

  if (!listingId) return actions;

  if (context === 'grid') {
    actions.push({
      key: 'view',
      label: 'Görüntüle',
      to: { path: `/listing/${listingId}` },
      uiClass: 'view-btn',
    });
  }

  if (!canFlow) {
    const label = context === 'detail' ? 'Mesaj Gönder' : 'İletişime geç';
    actions.push({
      key: 'message',
      label,
      to: msgTo,
      uiClass: context === 'grid' ? 'contact-btn' : 'action-button',
    });
    return actions;
  }

  for (const mode of modes) {
    const cta = MODE_CTA[mode];
    if (!cta) continue;
    actions.push({
      key: cta.key,
      label: context === 'detail' ? cta.labelDetail : cta.labelGrid,
      to: { path: cta.path, query: { listing_id: listingId } },
      uiClass: context === 'grid' ? cta.uiClassGrid : 'action-button',
    });
  }

  if (context === 'detail') {
    actions.unshift({
      key: 'message',
      label: 'Mesaj Gönder',
      to: msgTo,
      uiClass: 'action-button',
    });
  }

  return actions;
}
