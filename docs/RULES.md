# RULES

1. **Scratch yok**: Yeni özellik ekleme, büyük refactor yapma
2. **Küçük patch**: Sadece minimal, gerekli değişiklik
3. **Proof zorunlu**: Her değişiklik için test/smoke/proof kanıtı
4. **NO PASS, NO NEXT STEP**: Adım PASS olmadan devam etme
5. **Controller kural yazmaz**: Business logic → `HosGate`, controller sadece UI
6. **Shadow → enforce**: Breaking change için önce shadow, sonra enforce
7. **Kanıtsız merge yok**: PR'da proof olmadan merge yok
8. **Dokümantasyon güncelle**: Değişiklik yapıyorsan ilgili dokümanı güncelle
9. **Secrets korumalı**: `.gitignore`'da secrets var, asla commit etme
10. **Stack bozma**: Değişiklik yaparken çalışan stack'i bozma
11. **Scratch/root artifacts PR'da fail olur**: GitHub Actions repo guard workflow root'ta zip/rar/temp dosyaları engeller
12. **Archive sadece _archive altına**: Scratch dosyalar sadece `_archive/` klasörüne taşınır, root'ta kalmaz
13. **Runtime log'lar asla git'e girmez**: `storage/logs/*.log` dosyaları tracked olmamalı, gitignore'da olmalı
14. **PR merge için repo-guard + smoke PASS zorunlu**: GitHub Actions workflow'ları (repo-guard + smoke) PASS olmadan PR merge edilemez
15. **PR merge için conformance PASS zorunlu**: Mimari kurallar (world registry, disabled-world code, canonical docs, secrets) conformance gate'de PASS olmalı
16. **PR merge için contract (routes snapshot) PASS zorunlu**: API route'ları snapshot ile eşleşmeli, değişiklik varsa snapshot güncellenmeli
17. **PR merge için DB contract PASS zorunlu**: DB şeması snapshot ile eşleşmeli, değişiklik varsa snapshot güncellenmeli
18. **PR merge için error-contract PASS zorunlu**: Error response'ları standard envelope formatında olmalı (ok:false, error_code, request_id, details?)
19. **Yeni gate/health endpoint eklerken**: `docs/runbooks/incident.md` ve `ops/triage.ps1` güncellenmeli
20. **Repo layout değişikliği**: `docs/REPO_LAYOUT.md` ve `docs/ARCHITECTURE.md` güncellenmeli, `ops/doctor.ps1` PASS kalmalı
21. **Incident bundle zorunlu**: Incident'lerde incident bundle path veya içeriği eklenmeli
22. **SLO check release öncesi**: Release öncesi SLO check konsülte edilmeli; tekrarlayan FAIL/WARN durumunda incident bundle + runbook adımları gerekli
23. **Latency SLO warm-up ile**: Latency SLO değerlendirmesi warm-up ile ölçülmeli; sadece cold-start spike'ları release'i bloklamaz
24. **Release blockers availability/p95/error-rate**: Release kararı sadece availability, p95 latency ve error rate'e göre verilir; p50 bilgilendirme amaçlıdır ve Windows/Docker dev ortamında WARN gösterebilir
25. **PR merge için security-gate PASS zorunlu**: Route/middleware security audit PASS olmalı; admin/panel surface ve state-changing route'lar security policy'ye uygun olmalı
26. **PROD wildcard CORS yasak**: Production ortamında CORS_ALLOWED_ORIGINS env var ile strict allowlist kullanılmalı; wildcard (*) CORS sadece dev/local ortamında kullanılabilir
27. **Yeni ops gate/check entegrasyonu**: Yeni ops gate veya check eklendiğinde ops_status.ps1'e entegre edilmeli; unified dashboard tüm ops check'leri içermeli
28. **Auth surface auth-security gate PASS zorunlu**: Auth surface (admin/panel/auth endpoints) için auth-security gate PASS olmalı; unauthorized access protection ve rate limiting doğrulanmalı
29. **Tenant-boundary gate PASS zorunlu**: Tenant-boundary gate PASS olmalı; cross-tenant access prevention ve tenant isolation doğrulanmalı
30. **World-spine gate PASS zorunlu**: World-spine gate PASS olmalı; enabled worlds için route/controller surface ve ctx.world lock evidence, disabled worlds için controller directory yokluğu doğrulanmalı

