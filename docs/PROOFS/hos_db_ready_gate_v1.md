# HOS DB Ready Gate v1

## Goal
Hos-api container should not start until Postgres is fully ready. Migrations and server.js should not start until Postgres is ready.

## Changes Applied

### 1. work/hos/docker/docker-entrypoint.sh
**Simplified**: Entrypoint now waits for Postgres using `pg_isready` before executing the command.

**Logic**:
- Supports direct env vars: `DB_HOST`, `DB_PORT`, `DB_USER`
- Falls back to `DATABASE_URL` or `DATABASE_URL_FILE` parsing
- Extracts connection info and waits with `pg_isready`
- Only proceeds when Postgres is ready

### 2. work/hos/services/api/Dockerfile
**Already configured**:
- ✅ Installs `postgresql-client` for `pg_isready`
- ✅ Copies `docker/docker-entrypoint.sh` to `/usr/local/bin/docker-entrypoint.sh`
- ✅ Sets executable permissions
- ✅ Sets `ENTRYPOINT` to use the script

### 3. docker-compose.yml (hos-api)
**Already configured**:
- ✅ `depends_on` with `hos-db` service
- ✅ `condition: service_healthy` ensures DB health check passes before starting

## How It Works

1. **Docker Compose Health Check**: `hos-db` has a healthcheck that runs `pg_isready`. Docker Compose waits for this to pass before starting `hos-api`.

2. **Entrypoint Wait Loop**: Even after Docker Compose starts `hos-api`, the entrypoint script waits for Postgres to be ready using `pg_isready`:
   ```sh
   until pg_isready -h "$DB_HOST_VAL" -p "$DB_PORT_VAL" -U "$DB_USER_VAL"; do
     echo "[HOS] Postgres not ready yet..."
     sleep 2
   done
   ```

3. **Double Protection**: Both Docker Compose health check and entrypoint wait ensure Postgres is fully ready before migrations and server.js start.

## Verification Commands

```powershell
# 1) Rebuild hos-api
docker compose build hos-api

# 2) Restart hos-api
docker compose up -d hos-api

# 3) Check logs (should show "Postgres is ready" before server starts)
docker compose logs hos-api | Select-String -Pattern "Postgres|ready|HOS"

# 4) Verify health endpoint
curl.exe http://localhost:3000/v1/health
# Expected: HTTP 200

# 5) Check container status
docker compose ps hos-api
# Expected: Status should be "Up" (not restarting)
```

## Expected Results

1. **No 57P03 FATAL spam**: Postgres is ready before hos-api connects, eliminating connection errors
2. **Stable startup**: hos-api waits for DB before starting migrations and server
3. **Health endpoint works**: `/v1/health` returns HTTP 200 consistently
4. **Stack stability**: No more race conditions between DB startup and API startup

## Files Modified

1. `work/hos/docker/docker-entrypoint.sh` - Simplified and cleaned up (already had DB wait logic, just streamlined)

## Files Already Configured (No Changes Needed)

1. `work/hos/services/api/Dockerfile` - Already has entrypoint setup
2. `docker-compose.yml` - Already has `depends_on` with `service_healthy`

## Risk Assessment

1. **Low Risk**: Only infrastructure hardening, no domain logic changes
2. **Backward Compatible**: Existing DATABASE_URL parsing still works
3. **Non-Breaking**: If Postgres is already ready, wait loop exits immediately
4. **Deterministic**: Double protection ensures DB is always ready before API starts






