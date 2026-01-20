# H-OS Evrensel Kimlik (SSO) Standardı (TR) — “Bir hesap, sınırsız dünya”

Bu doküman, H-OS’un “evren” olmasının en kritik çıktısını kilitler:

> Kullanıcı **yeniden kayıt olmaz**. H-OS kimliğiyle evrendeki tüm dünyalara (Pazar, mesajlaşma, video, vb.) girer.

## 1) Hedef Kullanıcı Deneyimi
- Kullanıcı H-OS’ta **1 kere** kimlik oluşturur.
- Sonra herhangi bir dünyaya girince:
  - “Zaten evrendesin” → **SSO ile devam**
  - Dünya sadece “profil/ayar” gibi **minimum world kayıtları** açar (ilk girişte otomatik).

## 2) Temel Kavramlar (Canonical)
- **H-OS Identity**: Evrensel kullanıcı kimliği (`hos_user_id`)
- **World**: Pazar, Video, Mesajlaşma gibi uygulamalar
- **World Profile**: Dünyanın kullanıcıya ait minimal kaydı (dünya içi ayarlar)
- **Tenant**: Firma/kurum/mağaza gibi tenant scope
- **Membership**: Kullanıcının bir tenant içindeki rolü (owner/staff/customer vb.)

## 3) Kural: Dünya “Kayıt” Yapmaz, “Onboard” Yapar
Bir dünya (Pazar gibi) **kendi başına kayıt formu açmaz** (istisnalar hariç).
Doğru akış:
1) Kullanıcı H-OS’a login olur (SSO)
2) Dünya H-OS token’ını doğrular
3) Dünya “first-visit” ise `world_profile` oluşturur (otomatik)

## 4) H-OS’un Sorumlulukları
- **SSO/Identity Provider** olmak
- Token üretmek (JWT/OIDC benzeri)
- Token doğrulama standardı:
  - `iss`, `aud`, `sub(hos_user_id)`, `exp`, `iat`, `jti`
  - (opsiyonel) `tenant_memberships` claim veya “userinfo” endpoint
- **Role/Membership** kanunu:
  - kullanıcı hangi tenant’ta hangi rolde?
  - davet (invite) / onboarding politikaları

## 5) Pazar’ın (ve diğer dünyaların) Sorumlulukları
- Token doğrulama (signature + expiry + audience)
- `hos_user_id` ile local kullanıcı kaydına bağlamak:
  - öneri: `users.hos_user_id` alanı (ileride)
- İlk girişte otomatik world profile oluşturmak
- Tenant seçimi/rol seçimi UX’i (kullanıcı birden fazla tenant’a bağlı olabilir)

## 6) Yeniden kayıt ne zaman gerekir?
Normalde **hiçbir zaman**.
Sadece “ek doğrulama / ek onay” gerekir:
- KVKK/şartlar güncellendiyse → yeniden onay
- yüksek riskli işlemse → 2FA/KYC
- yeni tenant’a katılım → davet/owner onayı

## 7) Versiyonlama ve Uyumluluk
SSO standardı versiyonlanır:
- `hos_sso_version` (örn: `2025-12-28`)
- Breaking change kuralı:
  - önce shadow/compat mode
  - sonra enforce
  - bu doküman güncellenmeden değişiklik merge edilmez

## 8) Entegrasyon Modları (Kopmadan)
Bu doküman, `docs/tr/hos_pazar_entegrasyon_playbook.md` içindeki modlarla uyumludur:
- Mod-A: Embedded (bugün en güvenlisi)
- Mod-B: Hybrid (remote + fallback)
- Mod-C: Full remote (kanun servisleşir)

SSO için önerilen geçiş:
1) **Shadow**: Pazar hem kendi login’ini hem H-OS token doğrulamayı “log/telemetry” amaçlı dener
2) **Enforce**: Pazar login ekranında “H-OS ile giriş” birincil olur; local login sadece fallback


