const STATUS_LABELS = {
  placed: 'Siparis alindi',
  requested: 'Talep geldi',
  accepted: 'Onaylandi',
  rejected: 'Reddedildi',
  published: 'Yayinda',
  draft: 'Taslak',
};

const ACTION_LABELS = {
  accept: 'Onayla',
  reject: 'Reddet',
  working: 'Calisiyor...',
  view: 'Gor',
  detail: 'Detay',
  messages: 'Mesajlar',
  edit: 'Duzenle',
};

const BILLING_MODEL_LABELS = {
  one_time: 'Tek seferlik',
  per_day: 'Gunluk',
  per_night: 'Gecelik',
  per_month: 'Aylik',
  per_person: 'Kisi basi',
  per_hour: 'Saatlik',
  per_session: 'Seanslik',
  per_visit: 'Ziyaret basi',
};

export function getStatusLabel(status) {
  const key = String(status || '').trim().toLowerCase();
  return STATUS_LABELS[key] || (status || '—');
}

export function getActionLabel(key) {
  return ACTION_LABELS[key] || key;
}

export function getBillingModelLabel(value) {
  const key = String(value || '').trim().toLowerCase();
  if (!key) return '—';
  return BILLING_MODEL_LABELS[key] || value;
}
