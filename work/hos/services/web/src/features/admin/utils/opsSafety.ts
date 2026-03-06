export type RiskLevel = 'low' | 'medium' | 'critical';

export function trAdminError(input: unknown, fallback = 'Islem tamamlanamadi.'): string {
  const raw = String(input || '');
  if (!raw) return fallback;
  if (raw.includes('cannot_remove_last_owner')) return 'Bu firmada en az 1 aktif sahip kalmalidir.';
  if (raw.includes('membership_not_found')) return 'Uyelik kaydi bulunamadi.';
  if (raw.includes('user_not_found')) return 'Kullanici bulunamadi.';
  if (raw.includes('invalid_user_id')) return 'Gecersiz kullanici kimligi.';
  if (raw.includes('invalid_tenant_id')) return 'Gecersiz firma kimligi.';
  if (raw.includes('role_or_status_required')) return 'Rol veya durum degisikligi secilmelidir.';
  if (raw.includes('invalid_credentials')) return 'E-posta veya sifre hatali.';
  return raw;
}

export function confirmRiskyAction(args: {
  title: string;
  summary: string;
  risk: RiskLevel;
}): boolean {
  const text = `${args.title}\n${args.summary}`;
  if (args.risk === 'low') return window.confirm(text);
  if (args.risk === 'medium') return window.confirm(`${text}\n\nBu degisiklik yetki/erisim etkileyebilir.`);

  const ok = window.confirm(`${text}\n\nKritik islem. Devam etmek icin ikinci onay gerekecek.`);
  if (!ok) return false;
  const code = window.prompt('Onaylamak icin ONAY yazin:');
  return String(code || '').trim().toUpperCase() === 'ONAY';
}
