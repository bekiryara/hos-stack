# cleanup PASS

Tarih/Saat (İstanbul): 2026-01-07 23:34:03

## Komutlar + kısa çıktı

### docker compose ps

```
NAME                IMAGE                COMMAND                  SERVICE     CREATED          STATUS                    PORTS
stack-hos-api-1     stack-hos-api        "docker-entrypoint.s…"   hos-api     22 minutes ago   Up 12 minutes             127.0.0.1:3000->3000/tcp
stack-hos-db-1      postgres:16-alpine   "docker-entrypoint.s…"   hos-db      22 minutes ago   Up 22 minutes (healthy)   5432/tcp
stack-hos-web-1     stack-hos-web        "/docker-entrypoint.…"   hos-web     22 minutes ago   Up 22 minutes             127.0.0.1:3002->80/tcp
stack-pazar-app-1   stack-pazar-app      "docker-php-entrypoi…"   pazar-app   22 minutes ago   Up 22 minutes             127.0.0.1:8080->80/tcp
stack-pazar-db-1    postgres:16-alpine   "docker-entrypoint.s…"   pazar-db    22 minutes ago   Up 22 minutes (healthy)   5432/tcp
```

### curl.exe -sS -i http://localhost:3000/v1/health → 200 {"ok":true}

HTTP 200 `{"ok":true}`

### curl.exe -sS -i http://localhost:8080/up

HTTP 200
