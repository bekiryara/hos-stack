# Ops (work/hos) — RETIRED

Bu klasör artık **giriş noktası değildir**.

Amaç: “iki farklı çalıştırma yolu” yüzünden drift/kafa karışıklığı olmasın.

## Tek kanonik yol (kullanılacak tek yol)

Repo root’tan çalıştır:

```powershell
cd D:\stack
docker compose up -d --build
.\ops\ops.ps1 status
```

Obs (opsiyonel):

```powershell
.\ops\ops.ps1 up -StackProfile obs
```

## Not

`work/hos/docker-compose.yml` dosyası yalnızca obs bileşenleri için bir “component” olarak tutulur; core stack için kullanılmaz.



