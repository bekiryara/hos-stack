# GitHub Pages Merge Adımları

## Hızlı Yol: PR Oluştur ve Merge Et

### Adım 1: PR Oluştur
1. Tarayıcıda aç: https://github.com/bekiryara/hos-stack/compare/main...main-pages-update
2. "Create pull request" butonuna tıkla
3. Başlık: "Add GitHub Pages support + CODE_INDEX for AI access"
4. "Create pull request" butonuna tıkla

### Adım 2: PR'ı Merge Et
1. PR sayfasında "Merge pull request" butonuna tıkla
2. "Confirm merge" butonuna tıkla
3. PR merge edildi!

### Adım 3: GitHub Pages'i Aktif Et
1. https://github.com/bekiryara/hos-stack/settings/pages
2. "Source" dropdown'ından **"GitHub Actions"** seçeneğini seç
3. "Save" butonuna tıkla

### Adım 4: Deploy'u Bekle
1. Actions sekmesine git: https://github.com/bekiryara/hos-stack/actions
2. "GitHub Pages" workflow'unun çalıştığını gör
3. 1-2 dakika sonra site hazır: https://bekiryara.github.io/hos-stack/

---

## Alternatif: GitHub Web'den Dosya Ekleme

Eğer PR oluşturmak istemiyorsan, GitHub web'den direkt dosyaları ekleyebilirsin:

### Dosya 1: `.github/workflows/pages.yml`
1. https://github.com/bekiryara/hos-stack/new/main
2. Dosya yolu: `.github/workflows/pages.yml`
3. İçerik: (aşağıdaki dosyadan kopyala)

### Dosya 2: `docs/CODE_INDEX.md`
1. Dosya yolu: `docs/CODE_INDEX.md`
2. İçerik: (mevcut dosyadan kopyala)

### Dosya 3: `docs/index.md`
1. Dosya yolu: `docs/index.md`
2. İçerik: (mevcut dosyadan kopyala)

### Dosya 4: `docs/_config.yml`
1. Dosya yolu: `docs/_config.yml`
2. İçerik: (mevcut dosyadan kopyala)

---

## Dosya İçerikleri

Tüm dosyalar `main-pages-update` branch'inde hazır. GitHub web'den PR oluşturup merge etmek en kolay yol.


