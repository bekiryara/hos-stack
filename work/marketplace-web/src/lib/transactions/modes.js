/**
 * Transaction modes and action config — single source for labels, routes, query builders.
 * WP-NEXT: Listing ActionBar modes-aware. No hard-code in pages.
 */

export const TX_MODES = {
  SALE: 'sale',
  RENTAL: 'rental',
  RESERVATION: 'reservation',
};

/**
 * @param {object} listing
 * @returns {{ listing_id: string, quantity?: string, from?: string }}
 */
function buildOrderQuery(listing) {
  const id = String(listing?.id ?? '');
  if (!id) return {};
  return {
    listing_id: id,
    quantity: '1',
    from: 'listing',
  };
}

/**
 * @param {object} listing
 * @returns {{ listing_id: string, from?: string }}
 */
function buildRentalQuery(listing) {
  const id = String(listing?.id ?? '');
  if (!id) return {};
  return {
    listing_id: id,
    from: 'listing',
  };
}

/**
 * @param {object} listing
 * @returns {{ listing_id: string, from?: string }}
 */
function buildReservationQuery(listing) {
  const id = String(listing?.id ?? '');
  if (!id) return {};
  return {
    listing_id: id,
    from: 'listing',
  };
}

export const TX_ACTIONS = {
  sale: {
    label: 'Sipariş ver',
    route: '/order/create',
    buildQuery: buildOrderQuery,
  },
  rental: {
    label: 'Kirala',
    route: '/rental/create',
    buildQuery: buildRentalQuery,
  },
  reservation: {
    label: 'Rezervasyon yap',
    route: '/reservation/create',
    buildQuery: buildReservationQuery,
  },
};
