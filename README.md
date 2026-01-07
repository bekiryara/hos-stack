# Stack (H-OS + Pazar)

Bu repo, H-OS (evren hukuku) ve Pazar (ilk ticaret dünyası) servislerini birlikte çalıştırmak için standartlaştırılmış bir workspace'tir.

## 🚀 START HERE

**Yeni başlayanlar için:** [`docs/START_HERE.md`](docs/START_HERE.md) (7 kural seti)

**Kurallar:** [`docs/RULES.md`](docs/RULES.md) (10 temel kural)

**Doğrulama:** `.\ops\verify.ps1` (stack health check)

## Hızlı Başlangıç

### Canonical Compose (H-OS + Pazar)

```powershell
docker compose up -d --build
```

Bu komut root'taki `docker-compose.yml` dosyasını kullanır ve her iki servisi de başlatır:
- H-OS API: `http://localhost:3000`
- H-OS Web: `http://localhost:3002`
- Pazar App: `http://localhost:8080`

### Sadece H-OS (Standalone)

```powershell
cd work/hos
docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d --build
```

Detaylar: `work/hos/ops/README.md`

## Dokümantasyon Giriş Noktaları

### Günlük Çalışma
- **Pazar**: `work/pazar/docs/CURRENT.md` (açılacak ilk dosya)
- **H-OS**: `work/hos/docs/pazar/START_HERE.md` (ajan onboarding)

### Canonical Kaynaklar
- **World Registry**: `work/pazar/WORLD_REGISTRY.md` (dünya tanımları)
- **Pazar Docs**: `work/pazar/docs/README.md` (dokümantasyon navigasyonu)
- **H-OS Docs**: `work/hos/docs/` (H-OS dokümantasyonu)

### Operasyon
- **H-OS Ops**: `work/hos/ops/` (bootstrap, check, smoke, vb.)
- **Pazar Runbooks**: `work/pazar/docs/runbooks/` (operasyon runbook'ları)

## Repo Yapısı

```
.
├── docker-compose.yml          # CANONICAL compose (hos + pazar)
├── work/
│   ├── hos/                    # H-OS servisi
│   │   ├── docker-compose.yml  # H-OS standalone compose
│   │   ├── ops/                # Operasyon scriptleri
│   │   └── docs/               # H-OS dokümantasyonu
│   └── pazar/                  # Pazar servisi
│       ├── docs/               # Pazar dokümantasyonu
│       └── WORLD_REGISTRY.md   # Canonical world registry
└── docs/
    └── REPO_INVENTORY.md       # Repo envanter raporu
```

## Secrets ve Config

### H-OS Secrets
- Konum: `work/hos/secrets/`
- Detaylar: `work/hos/secrets/README.md`
- **ÖNEMLİ**: Gerçek secret değerleri repo'da tutulmamalı (local kullanım)

### Pazar .env
- Example: `work/pazar/docs/env.example`
- **ÖNEMLİ**: `.env` dosyası repo'da tutulmamalı (local kullanım)

## Releases

- **Version**: [`VERSION`](VERSION) (current: 0.1.0)
- **Changelog**: [`CHANGELOG.md`](CHANGELOG.md) (Keep a Changelog format)
- **Release Checklist**: [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) (pre-release verification)

## Daha Fazla Bilgi

- **Repo Envanter**: `docs/REPO_INVENTORY.md` (temizleme ve standartlaştırma detayları)
- **Pazar Runbooks**: `work/pazar/docs/runbooks/CURRENT.md`
- **H-OS Ops**: `work/hos/ops/README.md`

