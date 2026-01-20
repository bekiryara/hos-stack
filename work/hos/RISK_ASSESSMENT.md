# H-OS — Profesyonel Risk Değerlendirmesi (Kayıt)

Bu doküman, H-OS repo’su için yapılan güvenlik/operasyon odaklı risk değerlendirmesinin **kayıt** çıktısıdır.

## Kapsam
- API: `services/api`
- DB: Postgres + migrations
- Ops: `ops/*.ps1`
- Compose profilleri: `docker-compose*.yml`
- Observability: `services/observability`
- CI/CD: `.github/workflows/*`

## Skorlama
- Etki (1–5), Olasılık (1–5), Skor = Etki × Olasılık
- Seviye: Critical (≥20), High (15–19), Medium (8–14), Low (≤7)

## Executive Summary (özet)
Önceliklendirmede en yüksek riskler:
- **PII içeren dump/backup dosyalarının repo klasöründe bulunması**
- **Dolu secret dosyaları (JWT/DB/OAuth) ile sızıntı riski**
- **Self-register akışında rol/tenant onboarding boşlukları**
- **Promtail docker.sock mount gibi host-privilege etkisi yüksek bileşenler**

Not: Log toplama (Loki/Promtail) artık ayrı bir profile’dadır: `--profile logs` / `.\ops\bootstrap.ps1 -Logs`.
Bu sayede “default obs” akışı docker.sock erişimini otomatik olarak devreye almaz.

## Risk Register (özet)
| ID | Risk | Etki | Olasılık | Skor | Seviye | Kanıt | Önerilen aksiyon |
|---|---:|---:|---:|---:|---|---|---|
| R1 | PII içeren dump/backup dosyaları | 5 | 2 | 10 | Medium | `ops/restore_smoke.ps1` (başarı sonrası dump cleanup) + `ops/backup.ps1` (varsayılan repo dışı) | Varsayılanları koru, `-IncludeData` dump’larını paylaşma/zip’leme, periyodik temizlik |
| R2 | Secrets sızıntısı (local secrets dolu) | 5 | 4 | 20 | Critical | `secrets/*.txt` + `ops/secrets_from_env.ps1` | compromise varsay → rotate + secret-store standardı (CI/Vault → env → secrets files) |
| R3 | Tenant takeover / yetki yükseltme (onboarding) | 5 | 4 | 20 | Critical | `/v1/auth/register` rol modeli | “ilk kullanıcı owner, sonrası member” + invite/approval |
| R4 | Docker socket mount (Promtail) | 5 | 3 | 15 | High | promtail + docker.sock | prod’da devre dışı/izolasyon |
| R5 | Local-insecure default’ların prod’a taşınması | 4 | 3 | 12 | Medium | grafana anon/admin, port publish | prod compose standardı, network segmentasyonu |
| R6 | Metrics endpoint dışa açık | 3 | 4 | 12 | Medium | `GET /metrics` | internal-only scrape / auth |

## Hızlı kazanımlar (24–48 saat)
- Repo klasörünü paylaşmadan/zip’lemeden önce dump dosyalarını temizle (özellikle `backups-test/*.sql`). `restore_smoke` artık başarı sonrası dump’ı otomatik temizler; eski dump’lar manuel silinmeli.
- `secrets/*.txt` içeriğini compromise kabul et ve rotate et.
- Tenant onboarding politikasını netleştir (invite vs self-register).


