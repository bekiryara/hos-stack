/**
 * Standardized route builders for account record detail links.
 * Query keys: listing_id, status, created_at, updated_at (null when absent).
 */

function pickQuery(row) {
  return {
    listing_id: row.listing_id != null ? String(row.listing_id) : null,
    status: row.status != null ? String(row.status) : null,
    created_at: row.created_at != null ? String(row.created_at) : null,
    updated_at: row.updated_at != null ? String(row.updated_at) : null,
  };
}

export function buildOrderDetailLink(row) {
  const id = String(row.id);
  return {
    path: `/account/orders/${id}`,
    query: pickQuery(row),
  };
}

export function buildRentalDetailLink(row) {
  const id = String(row.id);
  return {
    path: `/account/rentals/${id}`,
    query: pickQuery(row),
  };
}

export function buildReservationDetailLink(row) {
  const id = String(row.id);
  return {
    path: `/account/reservations/${id}`,
    query: pickQuery(row),
  };
}
