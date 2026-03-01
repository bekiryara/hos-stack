export function formatDisplayDate(dateStr) {
  if (!dateStr) return '—';
  try {
    return new Date(dateStr).toLocaleString();
  } catch {
    return dateStr;
  }
}

export function formatDisplayPrice(amount, currency = 'TRY') {
  const numeric = Number(amount);
  if (!Number.isFinite(numeric)) return '—';
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: currency || 'TRY',
      maximumFractionDigits: 2,
    }).format(numeric);
  } catch {
    return `${numeric} ${currency || 'TRY'}`;
  }
}

export function formatShortId(value, head = 8) {
  const text = String(value || '').trim();
  if (!text) return '—';
  if (text.length <= head) return text;
  return `${text.slice(0, head)}...`;
}
