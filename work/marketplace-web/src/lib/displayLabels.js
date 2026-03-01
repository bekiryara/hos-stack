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
  messages: 'Mesajlar',
  edit: 'Duzenle',
};

export function getStatusLabel(status) {
  const key = String(status || '').trim().toLowerCase();
  return STATUS_LABELS[key] || (status || '—');
}

export function getActionLabel(key) {
  return ACTION_LABELS[key] || key;
}
