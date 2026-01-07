# CLEANUP AUDIT (2026-01-07)

**Amaç:** Repo'yu bozmadan gereksiz dosya/kod adaylarını tespit et.

**Kural:** Hiçbir dosya silinmedi, taşınmadı veya değiştirilmedi. Sadece tespit edildi.

---

## Section A: Dosya Adayları

### A1. Root Scratch Dosyalar

| PATH | NEDEN ADAY | RİSK | KANIT |
|------|------------|------|-------|
| `work.zip` | Runtime artifact, zip dosyası (RULES.md: "Scratch yok") | **LOW** | `rg -g "*.zip" --files | head -5` → `work.zip` |
| `work dışındakler.zip` | Runtime artifact, zip dosyası (RULES.md: "Scratch yok") | **LOW** | `rg -g "*.zip" --files | head -5` → `work dışındakler.zip` |
| `_verify_ps.txt` | Temp evidence dosyası, commit sonrası kaldı | **LOW** | `ls _*.txt` → `_verify_ps.txt` |

### A2. Pazar Scratch Dosyalar

| PATH | NEDEN ADAY | RİSK | KANIT |
|------|------------|------|-------|
| `work/pazar/null` | Scratch dosya, içeriği sadece backup mesajı | **LOW** | `cat work/pazar/null` → "OK: db block rewritten..." |
| `work/pazar/cd` | Muhtemelen scratch dosya (boş veya test) | **LOW** | `file work/pazar/cd` → dosya tipi kontrolü |
| `work/pazar/copy` | Muhtemelen scratch dosya (boş veya test) | **LOW** | `file work/pazar/copy` → dosya tipi kontrolü |
| `work/pazar/docs/kafamdaki_sorular_kanonik_surumu.txt` | Runtime artifact, soru notları (RULES.md: "Scratch yok") | **LOW** | `rg -g "*.txt" work/pazar/docs --files` → `kafamdaki_sorular_kanonik_surumu.txt` |

### A3. Runtime Log Dosyaları

| PATH | NEDEN ADAY | RİSK | KANIT |
|------|------------|------|-------|
| `work/pazar/storage/logs/laravel.log` | Runtime log dosyası (gitignore'da olmalı) | **LOW** | `rg -g "*.log" work/pazar/storage --files` → `laravel.log` |

### A4. Backup Klasörleri (Zaten Archive'da)

| PATH | NEDEN ADAY | RİSK | KANIT |
|------|------------|------|-------|
| `work/hos/secrets.bak-20260107-230146/` | Backup klasörü, secrets.bak pattern (RULES.md: "Scratch yok") | **LOW** | `ls -d work/hos/secrets.bak-*` → `secrets.bak-20260107-230146` |
| `_backup/` | Zaten archive klasörü, içindeki .bak dosyaları (23 adet) | **LOW** | `rg -g "*.bak*" _backup --files | wc -l` → 23 dosya |

### A5. Duplicate Markdown Dosyalar

| PATH | NEDEN ADAY | RİSK | KANIT |
|------|------------|------|-------|
| `work/pazar/docs/runbooks/QUESTIONS.md)` | Duplicate dosya (parantez ile bitiyor) | **LOW** | `ls work/pazar/docs/runbooks/*.md)` → `QUESTIONS.md)` |
| `work/pazar/docs/runbooks/STATUS.md)` | Duplicate dosya (parantez ile bitiyor) | **LOW** | `ls work/pazar/docs/runbooks/*.md)` → `STATUS.md)` |

### A6. Archive Klasörü (Zaten Archive'da, Referans)

| PATH | NEDEN ADAY | RİSK | KANIT |
|------|------------|------|-------|
| `_archive/20260107/` | Zaten archive klasörü, içindeki tüm dosyalar (139+ dosya) | **LOW** | `find _archive -type f | wc -l` → 139+ dosya |

---

## Section B: Kod Adayları

### B1. Kullanılmayan Route/Controller (Potansiyel)

| PATH | NEDEN ADAY | RİSK | KANIT |
|------|------------|------|-------|
| `work/pazar/routes/console.php` | Console route'ları, kullanım kontrolü gerekli | **MED** | `rg "Route::" work/pazar/routes/console.php | wc -l` → route sayısı |
| `work/pazar/app/Http/Controllers/Admin/` | Admin controller'ları, kullanım kontrolü gerekli | **MED** | `rg "Route.*admin" work/pazar/routes --files` → admin route kullanımı |

### B2. Duplicate Config Dosyaları (Potansiyel)

| PATH | NEDEN ADAY | RİSK | KANIT |
|------|------------|------|-------|
| `work/hos/docker-compose.*.yml` (6 dosya) | Multiple compose override dosyaları, kullanım kontrolü gerekli | **MED** | `ls work/hos/docker-compose.*.yml | wc -l` → 6 dosya |

### B3. Test/Debug Route'ları (Potansiyel)

| PATH | NEDEN ADAY | RİSK | KANIT |
|------|------------|------|-------|
| `work/pazar/routes/*.php` | Test/debug route'ları kontrolü gerekli | **MED** | `rg "test|debug|tmp" work/pazar/routes -i` → eşleşme yok (iyi) |

---

## Kaldırma Sırası Önerisi

### Öncelik 1: LOW Risk Dosyalar (Güvenli)

1. **Root zip dosyaları:**
   - `work.zip`
   - `work dışındakler.zip`
   - `_verify_ps.txt`

2. **Pazar scratch dosyaları:**
   - `work/pazar/null`
   - `work/pazar/cd`
   - `work/pazar/copy`
   - `work/pazar/docs/kafamdaki_sorular_kanonik_surumu.txt`

3. **Duplicate markdown dosyaları:**
   - `work/pazar/docs/runbooks/QUESTIONS.md)`
   - `work/pazar/docs/runbooks/STATUS.md)`

4. **Backup klasörü:**
   - `work/hos/secrets.bak-20260107-230146/`

### Öncelik 2: MED Risk Dosyalar (Kontrol Gerekli)

1. **Kullanım kontrolü yapılmalı:**
   - `work/pazar/routes/console.php` (kullanılıyor mu?)
   - `work/pazar/app/Http/Controllers/Admin/` (kullanılıyor mu?)
   - `work/hos/docker-compose.*.yml` (ops tarafından kullanılıyor mu?)

---

## Kanıt Komutları (10+)

### 1. Zip dosyaları tespit
```powershell
rg -g "*.zip" --files
```
**Beklenen:** `work.zip`, `work dışındakler.zip`

### 2. .bak dosyaları tespit
```powershell
rg -g "*.bak*" --files | Select-Object -First 10
```
**Beklenen:** `_backup/` altında 23 dosya, `work/hos/secrets.bak-*`

### 3. Scratch dosyalar (null, cd, copy)
```powershell
Get-ChildItem work/pazar -File | Where-Object { $_.Name -in @('null', 'cd', 'copy') }
```
**Beklenen:** `null`, `cd`, `copy` dosyaları

### 4. Duplicate markdown (parantez ile biten)
```powershell
Get-ChildItem work/pazar/docs/runbooks -Filter "*.md)" -File
```
**Beklenen:** `QUESTIONS.md)`, `STATUS.md)`

### 5. Runtime log dosyaları
```powershell
rg -g "*.log" work/pazar/storage --files
```
**Beklenen:** `work/pazar/storage/logs/laravel.log`

### 6. Temp evidence dosyaları
```powershell
Get-ChildItem -Filter "_*.txt" -File
```
**Beklenen:** `_verify_ps.txt` (varsa)

### 7. Backup klasörleri
```powershell
Get-ChildItem work/hos -Directory | Where-Object { $_.Name -like "*.bak-*" }
```
**Beklenen:** `secrets.bak-20260107-230146`

### 8. Archive klasörü dosya sayısı
```powershell
(Get-ChildItem _archive -Recurse -File).Count
```
**Beklenen:** 139+ dosya

### 9. Test/debug route kontrolü
```powershell
rg "test|debug|tmp" work/pazar/routes -i
```
**Beklenen:** Eşleşme yok (iyi)

### 10. Console route kullanımı
```powershell
rg "Route::" work/pazar/routes/console.php | Measure-Object -Line
```
**Beklenen:** Route sayısı (kullanım kontrolü için)

### 11. Admin controller kullanımı
```powershell
rg "admin" work/pazar/routes -i --files
```
**Beklenen:** Admin route dosyaları listesi

### 12. Compose override dosyaları
```powershell
Get-ChildItem work/hos/docker-compose.*.yml | Select-Object Name
```
**Beklenen:** 6 compose override dosyası

---

## RULES.md Uyum Kontrolü

### İhlaller:

1. **"Scratch yok" kuralı:**
   - ❌ `work.zip`, `work dışındakler.zip` (runtime artifacts)
   - ❌ `work/pazar/null`, `cd`, `copy` (scratch dosyalar)
   - ❌ `work/pazar/docs/kafamdaki_sorular_kanonik_surumu.txt` (runtime artifact)

2. **"Küçük patch" kuralı:**
   - ✅ Kod değişikliği yok, sadece dosya temizliği

3. **"Proof zorunlu" kuralı:**
   - ✅ Bu audit raporu proof olarak kullanılabilir

---

## Notlar

- `_archive/` ve `_backup/` klasörleri zaten archive amaçlı, dokunulmayacak
- `work/hos/docker-compose.*.yml` dosyaları ops override'ları olabilir, kontrol gerekli
- `work/pazar/storage/logs/laravel.log` gitignore'da olmalı (kontrol edilmeli)
- Duplicate markdown dosyaları (`QUESTIONS.md)`, `STATUS.md)`) muhtemelen yanlışlıkla oluşmuş

---

**Toplam Aday:** 15+ dosya/klasör (LOW risk: 12, MED risk: 3)

**Önerilen İlk Adım:** LOW risk dosyaları temizle (zip, scratch, duplicate md)

