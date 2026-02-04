## Catalog Invariants (Drift Guard) — Locked Rules

Bu doküman, **kategori → catalog schema → listing** zincirindeki “bozulursa sistem dağılır” kuralları tek yerde toplar.

### İnsan diliyle (neden var?)

Amaç: Kategori sayısı büyürken sistem bozulmasın.

- Yanlış veri oluşmasın (ilan yanlış kategoriye/kapalı kategoriye bağlanmasın)
- UI’da butonlar yanlış çıkmasın (flow vs iletişim sapmasın)
- Zamanla “her yere ayrı kural” yazılıp sistem karışmasın

- **Leaf-only**: Listing `category_id` **yalnız leaf** kategoriye bağlanabilir.
- **Active-only**: Listing `category_id` **yalnız `status=active`** kategoriye bağlanabilir.
- **Schema-driven attributes**: Listing `attributes_json` içindeki key’ler **yalnız** `category_filter_schema` ile izinli olmalı (whitelist). Bilinmeyen key → reject.
- **Required attributes**: `category_filter_schema.required=true` olan alanlar listing write’ta **boş olamaz**.
- **CTA determinism**: Published listing’lerde `attributes_json.interaction_mode` **boş olamaz** (UI CTA doğru çıksın). Eksikse deploy **FAIL**.

### Enforcement points (SSOT)

- **Write guard (backend SSOT)**: `work/pazar/routes/_helpers.php` → `pazar_guard_listing_catalog_write(...)`
- **Policy intent**: `work/pazar/config/category_flow_policy.php` + `work/pazar/routes/_helpers.php` → `pazar_category_intent_schema(...)`
- **Ops gate**: `ops/listing_contract_check.ps1` (published missing `interaction_mode` must be 0)

