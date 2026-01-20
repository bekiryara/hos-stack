# Ops (H-OS)

This directory intentionally contains **small, repeatable commands**. The goal is to avoid drift between machines and avoid "random docker run" usage.

## Canonical local start (dev)

From repo root:

```powershell
docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d --build
```

Health:

```powershell
curl.exe -sS -i http://localhost:3000/v1/health
```

## Production-oriented overrides (optional)

`docker-compose.prod.yml` disables anonymous Grafana and requires admin creds:

```powershell
$env:GRAFANA_ADMIN_USER='admin'
$env:GRAFANA_ADMIN_PASSWORD='admin'
docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.ports.yml up -d --build
```


This directory intentionally contains **small, repeatable commands**. The goal is to avoid drift between machines and avoid "random docker run" usage.

## Canonical local start (dev)

From repo root:

```powershell
docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d --build
```

Health:

```powershell
curl.exe -sS -i http://localhost:3000/v1/health
```

## Production-oriented overrides (optional)

`docker-compose.prod.yml` disables anonymous Grafana and requires admin creds:

```powershell
$env:GRAFANA_ADMIN_USER='admin'
$env:GRAFANA_ADMIN_PASSWORD='admin'
docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.ports.yml up -d --build
```



