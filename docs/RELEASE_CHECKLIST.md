# Release Checklist

Her release öncesi bu checklist'i tamamla.

## Pre-Release Checks

1. **repo-guard PASS**: GitHub Actions `repo-guard` workflow PASS olmalı
2. **smoke PASS**: GitHub Actions `smoke` workflow PASS olmalı
3. **ops/verify.ps1 PASS**: Local stack health check PASS olmalı
4. **PROOFS güncel**: `docs/PROOFS/cleanup_pass.md` son değişiklikleri içermeli
5. **Secrets tracked değil**: `git ls-files | grep -i secret` boş olmalı
6. **docker compose up/down temiz**: Stack temiz başlayıp kapanmalı (hata yok)

## Version & Changelog

7. **VERSION güncel**: `VERSION` dosyası yeni versiyonu içermeli
8. **CHANGELOG.md güncel**: `[Unreleased]` bölümü boşaltılıp yeni versiyon eklenmeli
9. **CHANGELOG.md format**: Keep a Changelog formatına uygun olmalı

## Documentation

10. **README.md güncel**: Releases bölümü doğru linkleri içermeli
11. **Breaking changes dokümante**: Varsa `docs/BREAKING_CHANGES.md` güncellenmeli

## Final

12. **Git tag**: `git tag -a v<version> -m "Release v<version>"` ve `git push --tags`

