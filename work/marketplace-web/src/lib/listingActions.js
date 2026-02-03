/**
 * Listing actions resolver (single source of truth).
 *
 * Goal: avoid duplicating "transaction_modes.includes(...)" logic across components.
 *
 * Inputs:
 * - listing.transaction_modes: ['sale'|'rental'|'reservation', ...]
 * - listing.attributes.interaction_mode: 'flow' | 'contact_only' (optional; policy-derived)
 *
 * Back-compat:
 * - If interaction_mode is missing, default to allowing flow actions (keeps previous UI behavior).
 */
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
  const interactionMode = attrs.interaction_mode ? String(attrs.interaction_mode) : '';

  const canFlow = interactionMode ? interactionMode === 'flow' : true; // keep old behavior if unset

  // Common destinations
  const msgTo = listingId ? buildMessagingTo(listingId, tenantId) : null;

  const actions = [];

  if (!listingId) return actions;

  if (context === 'grid') {
    actions.push({
      key: 'view',
      label: 'View',
      to: { path: `/listing/${listingId}` },
      uiClass: 'view-btn',
    });
  }

  // If policy explicitly says contact_only, do not show flow actions.
  // Instead, elevate contact as the primary CTA.
  if (!canFlow) {
    actions.push({
      key: 'contact',
      label: 'İletişime geç',
      to: msgTo,
      uiClass: context === 'grid' ? 'contact-btn' : 'action-button',
    });
    return actions;
  }

  // Flow actions: derived from transaction_modes
  if (modes.includes('reservation')) {
    actions.push({
      key: 'reservation',
      label: context === 'detail' ? 'Create Reservation' : 'Reserve',
      to: { path: '/reservation/create', query: { listing_id: listingId } },
      uiClass: context === 'grid' ? 'reserve-btn' : 'action-button',
    });
  }
  if (modes.includes('rental')) {
    actions.push({
      key: 'rental',
      label: context === 'detail' ? 'Create Rental' : 'Rent',
      to: { path: '/rental/create', query: { listing_id: listingId } },
      uiClass: context === 'grid' ? 'rent-btn' : 'action-button',
    });
  }
  if (modes.includes('sale')) {
    actions.push({
      key: 'sale',
      label: 'Buy',
      to: { path: '/order/create', query: { listing_id: listingId } },
      uiClass: context === 'grid' ? 'buy-btn' : 'action-button',
    });
  }

  // Messaging (secondary) — show on detail page by default.
  if (context === 'detail') {
    actions.unshift({
      key: 'message',
      label: 'Message Seller',
      to: msgTo,
      uiClass: 'action-button',
    });
  }

  return actions;
}

