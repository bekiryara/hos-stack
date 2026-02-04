# Kategori Sistemi — Mevcut Durum

Bu doküman, **kategori sisteminin** projede tam olarak nerede, nasıl kullanıldığını ve sınırlarını tek yerde toplar. Geliştirme öncesi “şu an ne var?” sorusunun cevabı burada.

---

## 1. Amaç ve Kapsam

- **Catalog Spine** (SPEC §6.2, WP-2): Marketplace kataloğunun omurgası kategoriler üzerinden.
- Kategoriler **hiyerarşik ağaç** (`parent_id`) ile yönetilir; ağaç “ne” sorusunu cevaplar (Konut, İş Yeri, Araç, Düğün Salonu vb.).
- **“Satılık / Kiralık / Rezervasyon”** gibi niyet/teklif türü **kategori ağacında değil**; `config/category_flow_policy.php` ve **intent-schema** API ile yönetilir (“2. sütun”).

---

## 2. Veritabanı

### 2.1 `categories` tablosu

| Alan         | Tip / Kısıt                         | Açıklama |
|-------------|--------------------------------------|----------|
| id          | bigint PK                            | Kalıcı; silinmez, değiştirilmez. |
| parent_id   | bigint nullable, FK → categories.id  | NULL = kök kategori. |
| slug        | string(100), UNIQUE                  | URL/policy eşlemesi; değiştirmek riskli. |
| name        | string(200)                          | Görünen ad (API’de `title` olarak döner). |
| vertical    | string(50) nullable                   | Dünya/dikey (örn. services). |
| status      | string(20) default 'active'           | active \| inactive \| deprecated. |
| sort_order  | integer default 0                    | Aynı parent altında sıra. |
| timestamps  |                                      | created_at, updated_at. |

- **İndeksler:** parent_id, (vertical, status), sort_order.
- **Kural:** Kategori silinmez; devre dışı bırakmak için `status = 'inactive'` kullanılır.

**Migration:** `work/pazar/database/migrations/2026_01_15_100000_create_categories_table.php`

### 2.2 `category_filter_schema` tablosu

Kategoriye göre **hangi filtrelerin** (attribute’ların) kullanılacağını tanımlar.

| Alan           | Tip / Kısıt                    | Açıklama |
|----------------|---------------------------------|----------|
| id             | bigint PK                       | |
| category_id    | bigint FK → categories.id      | |
| attribute_key  | string(100) FK → attributes.key | |
| status         | string(20) default 'active'     | active \| deprecated. |
| sort_order     | integer default 0               | |
| ui_component   | string nullable (migration ile)  | select, number, range, boolean, text. |
| required       | boolean (migration ile)          | İlan oluştururken zorunlu mu. |
| filter_mode    | string nullable (migration ile) | range vb. |
| rules_json     | json nullable (migration ile)    | options, min, max vb. |
| timestamps     |                                 | |

- **UNIQUE:** (category_id, attribute_key).
- **Migration:** `2026_01_15_100002_create_category_filter_schema_table.php`, `2026_01_16_100000_update_category_filter_schema_add_fields.php`

### 2.3 `attributes` tablosu

Filtre şemasında referans verilen anahtar tanımları (key, value_type, unit, description). Kategori sistemi bu tabloya FK ile bağlı; yeni filtre = önce attribute, sonra category_filter_schema satırı.

---

## 3. Backend API (Pazar)

### 3.1 Catalog endpoint’leri (`work/pazar/routes/api/02_catalog.php`)

| Method / Yol | Açıklama | Persona |
|--------------|----------|---------|
| GET /api/v1/categories | Tüm **aktif** kategorileri **ağaç** olarak döner. Düz liste değil; `children` iç içe. Alanlar: id, parent_id, slug, title (DB name), status. | guest |
| GET /api/v1/categories/{id}/filter-schema | Kategoriye özel filtre şeması (attribute_key, key, label, value_type, unit, type, rules, required, filter_mode vb.). Kategori yoksa 404. | guest |
| GET /api/v1/categories/{id}/intent-schema | Niyet/akış politikası: allowed_transaction_modes, default_offer_variant, offer_variants (Satılık/Kiralık/Rezervasyon, interaction_mode: contact_only \| flow). Kategori yoksa 404. | guest |

**Önemli:** Tekil kategori dönen **GET /api/v1/categories/{id}** yok. Tekil bilgi filter-schema veya intent-schema çağrısında ihtiyaç duyulursa backend bu endpoint’lerde kategori varlığını zaten kontrol ediyor; ek bilgi (slug/name) response içinde veriliyor.

### 3.2 Listings ile kategori kullanımı

- **GET /api/v1/listings:**  
  - `category_id` verilirse önce kategori **aktif** mi kontrol edilir; değilse 404.  
  - Filtreleme: `category_id` ve **tüm alt kategoriler** (recursive CTE: `pazar_category_descendant_cte_in_clause_sql`) dahil.  
  - `filters` / `attrs` kullanılıyorsa sadece bu kategori (ve altları) için tanımlı attribute_key’ler kabul edilir; bilinmeyen anahtar → 422 + unknown_keys.

- **POST /api/v1/listings (oluşturma):**  
  - `category_id` zorunlu, `exists:categories,id` ile doğrulanır.  
  - Kategorinin filter şemasındaki **required** attribute’lar eksikse 422.  
  - `pazar_category_intent_schema` ile transaction_modes ve offer_variant (attributes.offer_variant) doğrulanır; uyumsuzsa 422.

**Dosyalar:**  
- Okuma: `work/pazar/routes/api/03b_listings_read.php`  
- Yazma: `work/pazar/routes/api/03a_listings_write.php`

### 3.3 Helper fonksiyonlar (`work/pazar/routes/_helpers.php`)

| Fonksiyon | Açıklama |
|-----------|----------|
| pazar_build_tree($categories, $parentId) | Düz kategori listesini parent_id’ye göre O(n) indeksleyip ağaç yapısına çevirir. |
| pazar_category_descendant_ids($rootId) | Bir kök kategori ve tüm alt kategorilerinin ID’lerini recursive CTE ile döner. |
| pazar_category_descendant_cte_in_clause_sql($rootId) | Aynı mantığı SQL snippet + binding olarak verir; listing sorgularında category_id IN (...) için kullanılır. |
| pazar_category_intent_schema($categoryId) | Kategoriyi yukarı doğru gezip `category_flow_policy` kurallarını slug ile eşleştirir; CONTACT_ONLY/FLOW ve offer_variants döner. |

### 3.4 Category flow policy (`work/pazar/config/category_flow_policy.php`)

Slug’a göre (kategori ağacında yukarı çıkılarak) hangi niyet setinin uygulanacağı belirlenir:

- **vehicle:** Satılık (contact_only), Kiralık (flow).
- **konut:** Satılık, Kiralık, Turistik Günlük Kiralık (reservation/flow), Devren Satılık Konut.
- **isyeri:** Satılık, Kiralık, Devren Satılık, Devren Kiralık.
- **arsa:** Satılık, Kiralık, Kat Karşılığı Satılık.

“2. sütun” burada; ağaçta ayrı dal olarak kodlanmaz.

---

## 4. Frontend (marketplace-web)

### 4.1 Veri kaynağı ve cache

- **`work/marketplace-web/src/lib/catalogSpine.js`**  
  - `getCategoriesTree()`: GET /api/v1/categories, tek seferlik/önbellek.  
  - `getFilterSchemaForCategory(categoryId)`: GET .../filter-schema, categoryId bazlı önbellek.  
  - `getIntentSchemaForCategory(categoryId)`: GET .../intent-schema, categoryId bazlı önbellek.

- **`work/marketplace-web/src/api/domains/catalog.js`**  
  - getCategories(), getFilterSchema(categoryId), getIntentSchema(categoryId), searchListings(params), getListing(id), getListingOffers(listingId).  
  - client.js bu modülü re-export eder; sayfalar `api.getCategories()` vb. kullanır.

### 4.2 Ağaç yardımcıları (`work/marketplace-web/src/lib/categoryTree.js`)

- categoryLabel(node): title \| slug \| name.
- isLeafCategory(node): children yok mu.
- flattenCategoriesTree(tree): düz liste (id, slug, title, path, pathArray, isLeaf, node).
- findCategoryAncestorPathIds(tree, targetId): seçili kategoriye giden ata ID yolu (stepper breadcrumb için).
- getBreadcrumbsForPath(tree, pathIds): pathIds’e göre breadcrumb düğümleri.
- getChildrenAtPath(tree, pathIds): pathIds sonundaki düğümün çocukları.

Ağaç yapısı: `{ id, slug, title?, name?, children? }`.

### 4.3 Sayfalar ve bileşenler

| Yer | Kullanım |
|-----|----------|
| CreateListingPage | getCategoriesTree; kategori değişince getFilterSchemaForCategory + getIntentSchemaForCategory; form category_id ile gönderir; başarıda goToCategorySearch(categoryId) → /search/:categoryId. |
| CreateListingForm | categoriesTree, filterSchema, intentSchema; CategoryPickerStepper ile kategori seçimi; category-change emit. |
| CategoryPickerStepper | categoriesTree, modelValue (seçili id); breadcrumb + getChildrenAtPath; leaf’te seçim onayı; update:modelValue + category-change emit. |
| ListingsSearchPage | /search/:categoryId?; getCategoriesTree + categoryId varsa getFilterSchemaForCategory; arama params’ta category_id. |
| ListingDetailPage | listing.category_id için getCategoriesTree + findCategoryInTree ile categoryName (gösterim). |
| CategoriesPage | getCategoriesTree → CategoryTree’e categories prop. |
| CategoryTree | categories (ağaç); her düğümde /search/:id linki; title \| slug. |
| FiltersPanel | Kategoriye göre filtre listesi (filter schema’dan). |
| ListingsGrid / FirmListingsPanel / CreateListingSuccessBox | category_id gösterimi veya “Kategoriye git” linki. |

Kategori adı gösterimi: Çoğu yerde ağaç client’ta; ID’den isim bulmak için tüm ağaç indirilip findCategoryInTree benzeri gezinme yapılıyor (tekil GET /categories/{id} olmadığı için).

---

## 5. Ops / Admin

### 5.1 Kategori menüsü (`ops/_extras/tools/category_menu.ps1`)

- **Amaç:** Hiyerarşiyi (parent_id, sort_order, name, slug, status) SQL yazmadan yönetmek.
- **Kurallar:** Silme yok (status=inactive); ID’ler sabit; ROOT’a taşıma varsayılan kapalı (-AllowRootMove ile açılabilir).
- **Çalıştırma:** Docker üzerinden `docker compose exec -T pazar-db psql ...` (UTF-8).
- **Menü:** Hızlı taşıma, hızlı isim değiştir, kök listesi, ağaç, slug/id ile bulma, taşı/rename/slug/sort_order/status, path, alt ağaç, çocukları listele, catalog_integrity_check.
- **One-shot:** `-Action list_roots | tree | integrity | quick_list_vehicle | quick_list_real_estate | quick_list_service`.

### 5.2 Catalog integrity check (`ops/catalog_integrity_check.ps1`)

WP-74: Kategori ağacı ve şema tutarlılığı.

- **(A)** Döngü kontrolü: parent zincirinde döngü yok.
- **(B)** Yetim kontrolü: parent_id var olan bir kategoriye işaret ediyor.
- **(C)** Slug tekil: Aktif kategorilerde slug tek.
- **(D)** Şema: category_filter_schema.attribute_key, attributes.key’de var.
- **(E)** Kök invaryantları: vehicle, real-estate, service kökleri aktif mevcut.
- **(F)** Filter-schema erişilebilirliği: Aktif filter_schema satırları sadece aktif kategorilere bağlı.
- **(G)** Şema renderer tipleri: ui_component/filter_mode değerleri izin verilen kümede.

DB: env (DB_HOST, DB_PORT, …) veya Docker ile pazar-db container’ı.

---

## 6. Seed ve Kök Yapı

**CatalogSpineSeeder** (`work/pazar/database/seeders/CatalogSpineSeeder.php`):

- **Kökler:** vehicle, real-estate, service (ve isteğe bağlı products, accommodation).
- **Dallar örnek:** service → events → wedding-hall, bando; service → food → restaurant, kebab; vehicle → otomobil, karavan, … (leaf’ler *-ilan slug’lı); real-estate → konut, isyeri, arsa, bina, devre-mulk, turistik-tesis vb.
- Attributes ve category_filter_schema kayıtları da bu seeder ile eklenir/güncellenir.

Migrations ile bazı eski dallar inactive yapıldı (legacy real-estate, vehicle demo, duplicate real-estate leaf’ler).

---

## 7. Eksikler ve Sınırlamalar (geliştirme için notlar)

- **Tekil kategori endpoint’i yok:** GET /api/v1/categories/{id} tanımlı değil. Kategori adı/slug için client ya tüm ağacı alıp ağaçta arıyor ya da filter-schema/intent-schema response’undaki category_slug’a güveniyor.
- **Ağaç sadece aktif:** GET /api/v1/categories yalnızca status=active döner; inactive kategoriler ağaçta görünmez (admin/ops için category_menu ve psql kullanılıyor).
- **Slug değişimi:** Policy ve URL’leri etkiler; category_menu’da “TEHLIKELI” uyarısı var; mümkünse slug sabit tutulur.
- **Kategori silme:** Desteklenmez; inactive + filter_schema’nın aynı kategoride pasif edilmesi tercih edilir.
- **Dil/çoklu isim:** Sadece tek `name` alanı; çoklu dil veya slug/name ayrımı yok.
- **Frontend kategori adı:** Listing detay vb. için kategori adı, ağaç client’ta gezilerek bulunuyor; büyük ağaçta veya cache yoksa ek istek gerekebilir (şu an tek categories çağrısı + cache).

---

## 8. Dosya Referansları (özet)

| Bölüm | Dosya / Konum |
|-------|----------------|
| Categories migration | work/pazar/database/migrations/2026_01_15_100000_create_categories_table.php |
| Filter schema migration | work/pazar/database/migrations/2026_01_15_100002_create_category_filter_schema_table.php, 2026_01_16_100000_update_category_filter_schema_add_fields.php |
| Catalog API | work/pazar/routes/api/02_catalog.php |
| Helpers | work/pazar/routes/_helpers.php |
| Flow policy | work/pazar/config/category_flow_policy.php |
| Listings read/write | work/pazar/routes/api/03b_listings_read.php, 03a_listings_write.php |
| Seeder | work/pazar/database/seeders/CatalogSpineSeeder.php |
| Frontend catalog | work/marketplace-web/src/lib/catalogSpine.js, src/api/domains/catalog.js |
| Frontend tree utils | work/marketplace-web/src/lib/categoryTree.js |
| Kategori UI | work/marketplace-web/src/components/catalog/CategoryPickerStepper.vue, CategoryTree.vue |
| Ops menu | ops/_extras/tools/category_menu.ps1 |
| Integrity check | ops/catalog_integrity_check.ps1 |
| Genel kurallar | docs/CURRENT.md (Catalog / Search Final), docs/PRODUCT/PRODUCT_API_SPINE.md |

---

Bu doküman, kategori sisteminin **mevcut durumunu** tek referans olarak toplar. Geliştirme yaparken değişiklikler buraya işlenebilir veya “Hedef durum” ayrı bir bölüm/doküman olarak eklenebilir.
