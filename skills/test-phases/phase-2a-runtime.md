# Phase 2a: Runtime Health Checks

> **Model**: `sonnet` | **Tier**: 2 (Execute) | **Modifies Files**: No
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for service checks. Use `KillShell` to terminate unresponsive health checks. Can parallel with Phase 2.

Verify running services and runtime dependencies.

## When to Run

- Project has running services (web servers, databases)
- Docker containers are involved
- External service dependencies exist

## Execution Steps

### 1. Check Running Processes

```bash
# Check if app is running
pgrep -f "python.*app" || pgrep -f "node.*server" || pgrep -f "go run"

# Check listening ports
ss -tlnp | grep -E ":(3000|5000|8000|8080)"
```

### 2. Docker Health

```bash
if command -v docker &>/dev/null; then
  # List running containers
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

  # Check container health
  docker ps --filter "health=unhealthy" --format "{{.Names}}"
fi
```

### 3. Database Connectivity

```bash
# PostgreSQL
pg_isready -h localhost 2>/dev/null && echo "PostgreSQL: ✅"

# MySQL
mysqladmin ping -h localhost 2>/dev/null && echo "MySQL: ✅"

# Redis
redis-cli ping 2>/dev/null && echo "Redis: ✅"

# MongoDB
mongosh --eval "db.runCommand({ping:1})" 2>/dev/null && echo "MongoDB: ✅"
```

### 4. HTTP Endpoint Checks

```bash
# Check common health endpoints
for endpoint in "/health" "/api/health" "/healthz" "/_health"; do
  for port in 3000 5000 8000 8080; do
    curl -sf "http://localhost:$port$endpoint" && echo "http://localhost:$port$endpoint ✅"
  done
done 2>/dev/null
```

### 5. Environment Variables

```bash
# Check required env vars exist (don't print values!)
for var in DATABASE_URL API_KEY SECRET_KEY; do
  if [ -n "${!var}" ]; then
    echo "$var: ✅ (set)"
  else
    echo "$var: ❌ (missing)"
  fi
done
```

## Output

```
SERVICE HEALTH CHECK
────────────────────
Docker:     ✅ 3 containers running
PostgreSQL: ✅ accepting connections
Redis:      ✅ PONG
API:        ✅ http://localhost:8000/health
Env Vars:   ⚠️ API_KEY missing
```
