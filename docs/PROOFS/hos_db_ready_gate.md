# HOS DB Ready Gate v1

## Goal
Prevent hos-api container from starting before Postgres is fully ready. Eliminate 57P03 FATAL spam errors.

## Changes Applied

### 1. work/hos/docker/docker-entrypoint.sh (NEW)
**Created entrypoint script that:**
- Reads `DATABASE_URL` from environment or `DATABASE_URL_FILE` (Docker secrets)
- Parses `DATABASE_URL` to extract `host`, `port`, and `user` components
- Uses `pg_isready` to wait for Postgres to be ready before proceeding
- Executes the original command (node src/index.js) after DB is ready

**Key features:**
- Handles both `DATABASE_URL` env var and `DATABASE_URL_FILE` secret file
- Parses PostgreSQL connection string: `postgresql://user:password@host:port/database`
- Defaults to port 5432 if not specified
- Waits in 2-second intervals until `pg_isready` succeeds
- Non-blocking: only waits for readiness, not full migration

### 2. work/hos/services/api/Dockerfile
**Added:**
- `RUN apk add --no-cache postgresql-client` - Installs `pg_isready` command
- `COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh` - Copies entrypoint script
- `RUN chmod +x /usr/local/bin/docker-entrypoint.sh` - Makes script executable
- `ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]` - Sets entrypoint (runs before CMD)

**Note:** Entrypoint runs as root (before `USER node`), so `pg_isready` has necessary permissions.

### 3. docker-compose.yml (hos-api)
**Already configured:**
- `depends_on: hos-db: condition: service_healthy` - Ensures hos-db healthcheck passes before starting hos-api

**No changes needed** - this was already in place.

## How It Works

1. **Docker Compose Level**: `depends_on: condition: service_healthy` ensures hos-db healthcheck passes before hos-api container starts
2. **Container Entrypoint Level**: Entrypoint script waits for Postgres to be ready using `pg_isready` before executing `node src/index.js`
3. **Double Protection**: Even if healthcheck passes but DB isn't fully ready, entrypoint script provides additional wait
4. **Migration Safety**: Node.js app runs migrations after entrypoint completes, ensuring DB is ready

## Verification Commands

```powershell
# 1) Rebuild hos-api
docker compose build hos-api

# 2) Restart hos-api (will wait for DB)
docker compose up -d hos-api

# 3) Watch logs to see entrypoint waiting
docker compose logs -f hos-api

# 4) Verify health endpoint returns 200
curl.exe http://localhost:3000/v1/health

# 5) Check for 57P03 errors (should be zero)
docker compose logs hos-api | Select-String -Pattern "57P03|FATAL"
```

## Expected Results

1. **No 57P03 Errors**: All "connection refused" and "database does not exist" errors eliminated
2. **Stable Startup**: hos-api waits for DB before starting migrations and server
3. **Health Endpoint**: `/v1/health` always returns HTTP 200 (after initial startup)
4. **Stack Stability**: No more container restart loops due to DB connection failures

## Files Modified

1. `work/hos/docker/docker-entrypoint.sh` - NEW: Entrypoint script with DB readiness wait
2. `work/hos/services/api/Dockerfile` - Added postgresql-client, entrypoint script, and ENTRYPOINT directive
3. `docker-compose.yml` - No changes (depends_on already configured)

## Risk Assessment

1. **Low Risk**: Only adds a wait loop before starting the app
2. **No Domain Changes**: Pure infrastructure hardening
3. **Backward Compatible**: If DATABASE_URL parsing fails, script exits with error (fail-fast)
4. **Timeout Safety**: No timeout in entrypoint (relies on docker-compose healthcheck timeout), but pg_isready is fast

## DATABASE_URL Parsing Logic

The entrypoint script parses PostgreSQL connection strings:
- Format: `postgresql://user:password@host:port/database`
- Extracts: `user`, `host`, `port` (defaults to 5432)
- Uses: `pg_isready -h $host -p $port -U $user`

Example:
- Input: `postgresql://hos:password@hos-db:5432/hos`
- Parsed: `host=hos-db`, `port=5432`, `user=hos`




