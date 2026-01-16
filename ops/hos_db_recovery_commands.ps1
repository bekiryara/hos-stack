# HOS-DB CORRUPTION RECOVERY - Copy-Pastable Commands
# Run these commands in sequence in PowerShell

# A) VERIFY ROOT CAUSE
docker compose logs --tail 120 --timestamps hos-db
docker inspect stack-hos-db-1 --format "{{json .State.Health}}"
docker inspect hos-db --format "{{json .State.Health}}"

# B) IDENTIFY EXACT HOS-DB VOLUME
docker inspect stack-hos-db-1 --format "{{range .Mounts}}{{println .Name}}{{end}}"
docker inspect hos-db --format "{{range .Mounts}}{{println .Name}}{{end}}"
docker volume ls | findstr /i "hos"
# Expected: HOS_DB_VOLUME=hos_db_data
# SAFETY: If volume contains "pazar", STOP

# C) DEV RESET PROCEDURE
docker compose stop hos-api hos-db hos-web
docker volume rm hos_db_data
docker compose up -d hos-db
docker compose ps
docker compose logs --tail 120 --timestamps hos-db
docker inspect hos-db --format "{{.State.Health.Status}}"
docker compose up -d hos-api hos-web
curl.exe -i http://localhost:3000/v1/health

# D) RESTORE RC0 SIGNAL
.\ops\rc0_check.ps1
.\ops\ops_status.ps1

