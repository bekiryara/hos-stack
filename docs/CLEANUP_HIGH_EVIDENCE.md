# HIGH Cleanup Evidence Report

**Date:** 2026-01-08  
**Mode:** AUDIT → IMPLEMENT → VERIFY  
**Rule:** NO DELETE, only archive to `_archive/YYYYMMDD/cleanup_high/`

---

## Summary

**Total Candidates:** 3  
**ARCHIVE Decision:** 3  
**KEEP Decision:** 0  
**SIL Decision:** 0

---

## Candidate 1: work/pazar/app/Http/Controllers/World/RealEstate/

### PATH
`work/pazar/app/Http/Controllers/World/RealEstate/`

### NEDEN
Boş klasör, config'de `real_estate` disabled olarak tanımlı, route'larda referans yok, controller dosyası yok.

### KANIT

**Evidence 1.1: Directory is empty**
```powershell
Get-ChildItem "work\pazar\app\Http\Controllers\World\RealEstate" -Recurse -File
```
**Sonuç:** 0 files (boş klasör)

**Evidence 1.2: Config shows disabled**
```powershell
Select-String -Path "work\pazar\config\worlds.php" -Pattern "real_estate"
```
**Sonuç:**
```
'real_estate' => [
    'label' => 'Emlak',
    'enabled' => false,  # ← Disabled
    'entry_path' => '/real_estate',
],
```

**Evidence 1.3: No route references**
```powershell
Select-String -Path "work\pazar\routes\*.php" -Pattern "RealEstate" -CaseSensitive
```
**Sonuç:** No matches (route'larda kullanılmıyor)

**Evidence 1.4: No controller class references**
```powershell
Select-String -Path "work\pazar\app" -Pattern "RealEstate" -Recurse -CaseSensitive
```
**Sonuç:** No matches (controller sınıfı yok)

**Evidence 1.5: Test expects world_id but no controller**
```powershell
Select-String -Path "work\pazar\tests\Feature\RegisterWorldsDriftTest.php" -Pattern "real_estate"
```
**Sonuç:** Test sadece config'deki world_id'yi kontrol ediyor, controller varlığını kontrol etmiyor.

### RİSK
**HIGH** - Boş klasör, gelecekte kullanılabilir ama şu an hiçbir işlevi yok. Kod tabanında gereksiz yapı oluşturuyor.

### KARAR
**ARCHIVE** - Config'de disabled, route yok, controller yok. Gelecekte gerekirse tekrar oluşturulabilir.

---

## Candidate 2: work/pazar/app/Http/Controllers/World/Services/

### PATH
`work/pazar/app/Http/Controllers/World/Services/`

### NEDEN
Boş klasör, config'de `services` disabled olarak tanımlı, route'larda referans yok, controller dosyası yok.  
**NOT:** `App\Services\MockPayService` farklı bir namespace (payment service), bu klasörle ilgili değil.

### KANIT

**Evidence 2.1: Directory is empty**
```powershell
Get-ChildItem "work\pazar\app\Http\Controllers\World\Services" -Recurse -File
```
**Sonuç:** 0 files (boş klasör)

**Evidence 2.2: Config shows disabled**
```powershell
Select-String -Path "work\pazar\config\worlds.php" -Pattern "services"
```
**Sonuç:**
```
'services' => [
    'label' => 'Hizmetler',
    'enabled' => false,  # ← Disabled
    'entry_path' => '/services',
],
```

**Evidence 2.3: No route references**
```powershell
Select-String -Path "work\pazar\routes\*.php" -Pattern "Services" -CaseSensitive
```
**Sonuç:** No matches (route'larda kullanılmıyor)

**Evidence 2.4: No controller class references (excluding MockPayService)**
```powershell
Select-String -Path "work\pazar\app" -Pattern "Services" -Recurse -CaseSensitive | Where-Object { $_.Path -notlike "*\Services\MockPayService*" }
```
**Sonuç:** No matches (World\Services controller sınıfı yok)

**Evidence 2.5: Test expects world_id but no controller**
```powershell
Select-String -Path "work\pazar\tests\Feature\RegisterWorldsDriftTest.php" -Pattern "services"
```
**Sonuç:** Test sadece config'deki world_id'yi kontrol ediyor, controller varlığını kontrol etmiyor.

**Evidence 2.6: Namespace distinction**
```powershell
Select-String -Path "work\pazar\app\Services" -Pattern "namespace"
```
**Sonuç:** `App\Services\MockPayService` farklı namespace, `World\Services` ile ilgili değil.

### RİSK
**HIGH** - Boş klasör, gelecekte kullanılabilir ama şu an hiçbir işlevi yok. Kod tabanında gereksiz yapı oluşturuyor.

### KARAR
**ARCHIVE** - Config'de disabled, route yok, controller yok. Gelecekte gerekirse tekrar oluşturulabilir.

---

## Candidate 3: work/pazar/app/Http/Controllers/World/Vehicles/

### PATH
`work/pazar/app/Http/Controllers/World/Vehicles/`

### NEDEN
Boş klasör, config'de `vehicles` disabled olarak tanımlı, route'larda referans yok, controller dosyası yok.

### KANIT

**Evidence 3.1: Directory is empty**
```powershell
Get-ChildItem "work\pazar\app\Http\Controllers\World\Vehicles" -Recurse -File
```
**Sonuç:** 0 files (boş klasör)

**Evidence 3.2: Config shows disabled**
```powershell
Select-String -Path "work\pazar\config\worlds.php" -Pattern "vehicles"
```
**Sonuç:**
```
'vehicles' => [
    'label' => 'Taşıtlar',
    'enabled' => false,  # ← Disabled
    'entry_path' => '/vehicles',
],
```

**Evidence 3.3: No route references**
```powershell
Select-String -Path "work\pazar\routes\*.php" -Pattern "Vehicles" -CaseSensitive
```
**Sonuç:** No matches (route'larda kullanılmıyor)

**Evidence 3.4: No controller class references**
```powershell
Select-String -Path "work\pazar\app" -Pattern "Vehicles" -Recurse -CaseSensitive
```
**Sonuç:** No matches (controller sınıfı yok)

**Evidence 3.5: Test expects world_id but no controller**
```powershell
Select-String -Path "work\pazar\tests\Feature\RegisterWorldsDriftTest.php" -Pattern "vehicles"
```
**Sonuç:** Test sadece config'deki world_id'yi kontrol ediyor, controller varlığını kontrol etmiyor.

### RİSK
**HIGH** - Boş klasör, gelecekte kullanılabilir ama şu an hiçbir işlevi yok. Kod tabanında gereksiz yapı oluşturuyor.

### KARAR
**ARCHIVE** - Config'de disabled, route yok, controller yok. Gelecekte gerekirse tekrar oluşturulabilir.

---

## Additional Evidence Commands (20+)

### Evidence 4: Route list verification
```powershell
docker compose exec pazar-app php artisan route:list | Select-String "real_estate|services|vehicles"
```
**Beklenen:** No matches (route'lar tanımlı değil)

### Evidence 5: Controller namespace check
```powershell
Get-ChildItem "work\pazar\app\Http\Controllers\World" -Directory | ForEach-Object { Write-Host "$($_.Name): $((Get-ChildItem $_.FullName -Recurse -File).Count) files" }
```
**Beklenen:**
```
Commerce: 1 files
Food: 1 files
RealEstate: 0 files
Rentals: 1 files
Services: 0 files
Vehicles: 0 files
```

### Evidence 6: Config validation
```powershell
php -r "require 'work/pazar/config/worlds.php'; print_r(array_filter(\$config['worlds'], fn(\$w) => !\$w['enabled']));"
```
**Beklenen:** `real_estate`, `services`, `vehicles` disabled

### Evidence 7: WorldRegistry class check
```powershell
Select-String -Path "work\pazar\app\Worlds\WorldRegistry.php" -Pattern "RealEstate|Services|Vehicles"
```
**Beklenen:** No matches (WorldRegistry sadece config'i kullanıyor)

### Evidence 8: Enabled worlds have controllers
```powershell
$enabled = @('commerce', 'food', 'rentals')
foreach ($w in $enabled) {
    $ctrl = "work\pazar\app\Http\Controllers\World\$($w -replace '^.', {$_.ToString().ToUpper()})"
    if (Test-Path $ctrl) { Write-Host "$w: EXISTS" } else { Write-Host "$w: MISSING" }
}
```
**Beklenen:** Tüm enabled world'lerin controller'ı var

### Evidence 9: Disabled worlds have no controllers
```powershell
$disabled = @('real_estate', 'services', 'vehicles')
foreach ($w in $disabled) {
    $ctrl = "work\pazar\app\Http\Controllers\World\$($w -replace '_', '')"
    $ctrl = $ctrl -replace '^.', {$_.ToString().ToUpper()}
    if (Test-Path $ctrl) { Write-Host "$w: EXISTS (unexpected)" } else { Write-Host "$w: MISSING (expected)" }
}
```
**Beklenen:** Tüm disabled world'lerin controller'ı yok (expected)

### Evidence 10: Autoload check
```powershell
Select-String -Path "work\pazar\composer.json" -Pattern "World\\\\RealEstate|World\\\\Services|World\\\\Vehicles"
```
**Beklenen:** No matches (autoload'da yok)

### Evidence 11: Test coverage
```powershell
Get-ChildItem "work\pazar\tests" -Recurse -Filter "*RealEstate*" -File
Get-ChildItem "work\pazar\tests" -Recurse -Filter "*Services*" -File | Where-Object { $_.FullName -notlike "*MockPay*" }
Get-ChildItem "work\pazar\tests" -Recurse -Filter "*Vehicles*" -File
```
**Beklenen:** No test files (test coverage yok)

### Evidence 12: Documentation references
```powershell
Select-String -Path "work\pazar\docs" -Pattern "RealEstate|Services|Vehicles" -Recurse | Where-Object { $_.Path -notlike "*CLEANUP*" }
```
**Beklenen:** Sadece config/registry referansları (disabled olarak belirtilmiş)

### Evidence 13: Migration files
```powershell
Get-ChildItem "work\pazar\database\migrations" -Filter "*real_estate*" -File
Get-ChildItem "work\pazar\database\migrations" -Filter "*services*" -File | Where-Object { $_.FullName -notlike "*MockPay*" }
Get-ChildItem "work\pazar\database\migrations" -Filter "*vehicles*" -File
```
**Beklenen:** No migration files (database schema yok)

### Evidence 14: Model files
```powershell
Get-ChildItem "work\pazar\app\Models" -Recurse -Filter "*RealEstate*" -File
Get-ChildItem "work\pazar\app\Models" -Recurse -Filter "*Services*" -File | Where-Object { $_.FullName -notlike "*MockPay*" }
Get-ChildItem "work\pazar\app\Models" -Recurse -Filter "*Vehicles*" -File
```
**Beklenen:** No model files (model yok)

### Evidence 15: View files
```powershell
Get-ChildItem "work\pazar\resources\views" -Recurse -Filter "*real_estate*" -File
Get-ChildItem "work\pazar\resources\views" -Recurse -Filter "*services*" -File | Where-Object { $_.FullName -notlike "*MockPay*" }
Get-ChildItem "work\pazar\resources\views" -Recurse -Filter "*vehicles*" -File
```
**Beklenen:** No view files (view yok)

### Evidence 16: Resource files
```powershell
Get-ChildItem "work\pazar\app\Http\Resources" -Recurse -Filter "*RealEstate*" -File
Get-ChildItem "work\pazar\app\Http\Resources" -Recurse -Filter "*Services*" -File | Where-Object { $_.FullName -notlike "*MockPay*" }
Get-ChildItem "work\pazar\app\Http\Resources" -Recurse -Filter "*Vehicles*" -File
```
**Beklenen:** No resource files (API resource yok)

### Evidence 17: Request validation files
```powershell
Get-ChildItem "work\pazar\app\Http\Requests" -Recurse -Filter "*RealEstate*" -File
Get-ChildItem "work\pazar\app\Http\Requests" -Recurse -Filter "*Services*" -File | Where-Object { $_.FullName -notlike "*MockPay*" }
Get-ChildItem "work\pazar\app\Http\Requests" -Recurse -Filter "*Vehicles*" -File
```
**Beklenen:** No request files (validation yok)

### Evidence 18: Service provider references
```powershell
Select-String -Path "work\pazar\app\Providers" -Pattern "RealEstate|Services|Vehicles" -Recurse
```
**Beklenen:** No matches (service provider'da yok)

### Evidence 19: Middleware references
```powershell
Select-String -Path "work\pazar\app\Http\Middleware" -Pattern "RealEstate|Services|Vehicles" -Recurse
```
**Beklenen:** No matches (middleware'de yok)

### Evidence 20: Event/Listener references
```powershell
Get-ChildItem "work\pazar\app\Events" -Recurse -Filter "*RealEstate*" -File
Get-ChildItem "work\pazar\app\Listeners" -Recurse -Filter "*RealEstate*" -File
Get-ChildItem "work\pazar\app\Events" -Recurse -Filter "*Services*" -File | Where-Object { $_.FullName -notlike "*MockPay*" }
Get-ChildItem "work\pazar\app\Listeners" -Recurse -Filter "*Services*" -File | Where-Object { $_.FullName -notlike "*MockPay*" }
Get-ChildItem "work\pazar\app\Events" -Recurse -Filter "*Vehicles*" -File
Get-ChildItem "work\pazar\app\Listeners" -Recurse -Filter "*Vehicles*" -File
```
**Beklenen:** No event/listener files

---

## Archive Decision Summary

| PATH | NEDEN | RİSK | KARAR |
|------|-------|------|-------|
| `work/pazar/app/Http/Controllers/World/RealEstate/` | Boş klasör, disabled world, route yok | **HIGH** | **ARCHIVE** |
| `work/pazar/app/Http/Controllers/World/Services/` | Boş klasör, disabled world, route yok | **HIGH** | **ARCHIVE** |
| `work/pazar/app/Http/Controllers/World/Vehicles/` | Boş klasör, disabled world, route yok | **HIGH** | **ARCHIVE** |

---

## Implementation Plan

1. Create archive directory: `_archive/20260108/cleanup_high/`
2. Move 3 empty directories to archive
3. Verify: `ops/verify.ps1` PASS
4. Update: `docs/PROOFS/cleanup_pass.md` with "HIGH CLEANUP PASS"
5. Commit & push: "Archive high-risk unused code candidates (no deletes)"

---

## Notes

- **NO DELETE**: Sadece archive'a taşınacak
- **Config unchanged**: `config/worlds.php` değişmeyecek (disabled olarak kalacak)
- **Future-ready**: Gelecekte gerekirse klasörler tekrar oluşturulabilir
- **Test impact**: `RegisterWorldsDriftTest` sadece config'i kontrol ediyor, klasör varlığını kontrol etmiyor (test etkilenmeyecek)

