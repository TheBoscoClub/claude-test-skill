# Phase 2a: Runtime Health Checks

> **Model**: `sonnet` | **Tier**: 2 (Execute) | **Modifies Files**: No
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for service checks (use `timeout` to prevent hangs). Can parallel with Phase 2.

Verify running services and runtime dependencies by dynamically discovering what the project deploys, then checking each component.

---

## When to Run

- Project has docker-compose.yml, Dockerfile, Procfile, or systemd service definitions
- Project has web server configuration or startup scripts
- Phase 1 discovery found running services or install-manifest.json
- User explicitly requests runtime checks

## Step 1: Discover Expected Services

Do NOT hardcode ports or process names. Discover them from the project's own configuration.

### 1a. Docker Compose Services

```bash
if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ] || [ -f compose.yml ] || [ -f compose.yaml ]; then
  COMPOSE_FILE=$(ls docker-compose.yml docker-compose.yaml compose.yml compose.yaml 2>/dev/null | head -1)
  echo "=== Docker Compose services from $COMPOSE_FILE ==="

  # Extract service names
  grep -E '^\s+\w+:' "$COMPOSE_FILE" | sed 's/:.*//' | sed 's/^ *//' | while read svc; do
    echo "  Service: $svc"
  done

  # Extract port mappings (host:container format)
  grep -E '^\s+- "[0-9]+:[0-9]+"' "$COMPOSE_FILE" | sed 's/.*"//;s/".*//' || \
  grep -E '^\s+- [0-9]+:[0-9]+' "$COMPOSE_FILE" | awk '{print $2}'
fi
```

### 1b. Package.json Scripts

```bash
if [ -f package.json ]; then
  echo "=== Node.js port discovery ==="
  # Check start/dev scripts for --port or PORT= patterns
  grep -E '"(start|dev|serve)"' package.json | grep -oE '(--port|PORT=|:)[0-9]+' | grep -oE '[0-9]+'
  # Check for PORT in .env files
  grep -iE '^PORT=' .env .env.local .env.development 2>/dev/null | head -5
fi
```

### 1c. Python Application Ports

```bash
if [ -f requirements.txt ] || [ -f pyproject.toml ] || [ -f setup.py ]; then
  echo "=== Python port discovery ==="
  # Flask/Django/FastAPI/uvicorn port detection
  grep -rE '(\.run\(|uvicorn|gunicorn|--port|--bind)' *.py app/ src/ 2>/dev/null | grep -oE '(port=|--port |--bind .*:)[0-9]+' | grep -oE '[0-9]+' | sort -u
  # Check Procfile
  if [ -f Procfile ]; then
    echo "Procfile entries:"
    cat Procfile
    grep -oE '(--port |--bind .*:|:)[0-9]+' Procfile | grep -oE '[0-9]+'
  fi
fi
```

### 1d. Environment Variable Ports

```bash
echo "=== Environment variable port discovery ==="
for envfile in .env .env.local .env.production .env.development; do
  if [ -f "$envfile" ]; then
    # Extract PORT-like variables (mask actual values of secrets)
    grep -iE '^[A-Z_]*PORT[A-Z_]*=' "$envfile" | while read line; do
      varname=$(echo "$line" | cut -d= -f1)
      varval=$(echo "$line" | cut -d= -f2)
      echo "  $envfile: $varname=$varval"
    done
  fi
done
```

### 1e. Install Manifest Services

```bash
if [ -f install-manifest.json ]; then
  echo "=== install-manifest.json services ==="
  # Extract systemd service names
  grep -oE '"[a-z][-a-z0-9]*\.service"' install-manifest.json | tr -d '"'
  # Extract ports
  grep -iE '"port"' install-manifest.json
fi
```

### 1f. Systemd Unit Files in Project

```bash
echo "=== Systemd unit files in project ==="
find . -maxdepth 3 -name "*.service" -type f 2>/dev/null | while read unitfile; do
  echo "  Unit file: $unitfile"
  grep -E '^ExecStart=' "$unitfile" | head -1
done
```

**Store all discovered ports in a variable for later steps.** If no ports are discovered, skip HTTP endpoint checks and report "No services detected."

## Step 2: Check Running Processes

Match running processes against what the project actually deploys. Use the discovered service names, not generic patterns.

```bash
echo "=== Running process check ==="

# Check docker containers if docker-compose exists
if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ] || [ -f compose.yml ] || [ -f compose.yaml ]; then
  if command -v docker &>/dev/null; then
    COMPOSE_FILE=$(ls docker-compose.yml docker-compose.yaml compose.yml compose.yaml 2>/dev/null | head -1)
    PROJECT_NAME=$(basename "$(pwd)")

    echo "--- Docker containers ---"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null

    # Check for unhealthy containers
    UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null)
    if [ -n "$UNHEALTHY" ]; then
      echo "FINDING: Unhealthy containers detected:"
      echo "$UNHEALTHY" | while read name; do
        echo "  - $name"
        docker inspect --format='{{.State.Health.Log}}' "$name" 2>/dev/null | tail -1
      done
    fi

    # Check for expected but missing containers
    grep -E '^\s+\w+:' "$COMPOSE_FILE" | sed 's/:.*//' | sed 's/^ *//' | while read svc; do
      if ! docker ps --format "{{.Names}}" 2>/dev/null | grep -q "$svc"; then
        echo "FINDING: Expected service '$svc' from $COMPOSE_FILE is not running"
      fi
    done
  else
    echo "FINDING: docker-compose.yml exists but docker command not available"
  fi
fi

# Check systemd services from install-manifest.json
if [ -f install-manifest.json ]; then
  echo "--- Systemd services ---"
  grep -oE '"[a-z][-a-z0-9]*\.service"' install-manifest.json | tr -d '"' | while read svc; do
    STATUS=$(systemctl is-active "$svc" 2>/dev/null)
    if [ "$STATUS" = "active" ]; then
      echo "  $svc: RUNNING"
    else
      echo "FINDING: Service $svc expected (install-manifest.json) but status=$STATUS"
    fi
  done
fi

# Check listening ports match discovered ports
echo "--- Listening ports ---"
if command -v ss &>/dev/null; then
  ss -tlnp 2>/dev/null | grep -E '^LISTEN' | awk '{print $4}' | grep -oE '[0-9]+$' | sort -un
elif command -v netstat &>/dev/null; then
  netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | grep -oE '[0-9]+$' | sort -un
fi
```

## Step 3: Health Endpoint Discovery

Probe discovered ports for standard health endpoints. Only check ports found in Step 1.

```bash
echo "=== Health endpoint probing ==="

# DISCOVERED_PORTS should be populated from Step 1
# Example: DISCOVERED_PORTS="8000 3000 5432"

HEALTH_PATHS="/health /healthz /api/health /status /api/status /readyz /api/v1/health"

if command -v curl &>/dev/null; then
  for port in $DISCOVERED_PORTS; do
    FOUND_HEALTH=false
    for path in $HEALTH_PATHS; do
      RESPONSE=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "http://localhost:$port$path" 2>/dev/null)
      if [ "$RESPONSE" = "200" ]; then
        echo "  http://localhost:$port$path -> 200 OK"
        FOUND_HEALTH=true
        # Capture response body for structured health info
        BODY=$(curl -sf --connect-timeout 3 --max-time 5 "http://localhost:$port$path" 2>/dev/null | head -c 500)
        if echo "$BODY" | grep -qiE '"status"'; then
          echo "    Response: $BODY"
        fi
        break
      fi
    done
    if [ "$FOUND_HEALTH" = "false" ]; then
      # Try root path as fallback
      ROOT_CODE=$(curl -sf -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "http://localhost:$port/" 2>/dev/null)
      if [ -n "$ROOT_CODE" ] && [ "$ROOT_CODE" != "000" ]; then
        echo "  http://localhost:$port/ -> $ROOT_CODE (no health endpoint found)"
      else
        echo "FINDING: Port $port is expected but not responding to HTTP"
      fi
    fi
  done
elif command -v wget &>/dev/null; then
  echo "  (using wget - curl not available)"
  for port in $DISCOVERED_PORTS; do
    wget -q --spider --timeout=3 "http://localhost:$port/health" 2>/dev/null && \
      echo "  http://localhost:$port/health -> OK" || \
      echo "FINDING: Port $port /health not responding"
  done
else
  echo "FINDING: Neither curl nor wget available for HTTP health checks"
fi
```

## Step 4: Database Connectivity

Discover database connections from project config, then verify connectivity.

```bash
echo "=== Database connectivity ==="

# Discover DATABASE_URL from env files and docker-compose
DB_URL=""
for envfile in .env .env.local .env.production .env.development; do
  if [ -f "$envfile" ]; then
    FOUND=$(grep -E '^DATABASE_URL=' "$envfile" 2>/dev/null | tail -1 | cut -d= -f2-)
    if [ -n "$FOUND" ]; then
      DB_URL="$FOUND"
      # Detect DB type from URL (mask credentials in output)
      DB_TYPE=$(echo "$DB_URL" | grep -oE '^[a-z]+')
      echo "  Found DATABASE_URL in $envfile (type: $DB_TYPE)"
    fi
  fi
done

# Check docker-compose for database services
if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ] || [ -f compose.yml ] || [ -f compose.yaml ]; then
  COMPOSE_FILE=$(ls docker-compose.yml docker-compose.yaml compose.yml compose.yaml 2>/dev/null | head -1)
  grep -qiE '(postgres|mysql|mariadb|mongo|redis)' "$COMPOSE_FILE" 2>/dev/null && \
    echo "  Database services detected in $COMPOSE_FILE"
fi

# PostgreSQL
if echo "$DB_URL" | grep -qi 'postgres' || grep -qiE 'postgres' docker-compose.yml 2>/dev/null; then
  if command -v pg_isready &>/dev/null; then
    PG_HOST=$(echo "$DB_URL" | grep -oE '@[^:/]+' | tr -d '@' || echo "localhost")
    PG_PORT=$(echo "$DB_URL" | grep -oE ':[0-9]+/' | tr -d ':/' || echo "5432")
    pg_isready -h "${PG_HOST:-localhost}" -p "${PG_PORT:-5432}" 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "  PostgreSQL: accepting connections on ${PG_HOST:-localhost}:${PG_PORT:-5432}"
    else
      echo "FINDING: PostgreSQL not accepting connections on ${PG_HOST:-localhost}:${PG_PORT:-5432}"
    fi
  else
    echo "  PostgreSQL detected but pg_isready not available"
  fi
fi

# MySQL/MariaDB
if echo "$DB_URL" | grep -qi 'mysql' || grep -qiE '(mysql|mariadb)' docker-compose.yml 2>/dev/null; then
  if command -v mysqladmin &>/dev/null; then
    mysqladmin ping -h localhost --silent 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "  MySQL/MariaDB: accepting connections"
    else
      echo "FINDING: MySQL/MariaDB not accepting connections"
    fi
  elif command -v mariadb-admin &>/dev/null; then
    mariadb-admin ping -h localhost --silent 2>/dev/null && \
      echo "  MariaDB: accepting connections" || \
      echo "FINDING: MariaDB not accepting connections"
  fi
fi

# Redis
if grep -qiE 'redis' docker-compose.yml 2>/dev/null || grep -qiE 'REDIS_URL' .env 2>/dev/null; then
  if command -v redis-cli &>/dev/null; then
    REDIS_RESPONSE=$(redis-cli ping 2>/dev/null)
    if [ "$REDIS_RESPONSE" = "PONG" ]; then
      echo "  Redis: responding (PONG)"
    else
      echo "FINDING: Redis not responding"
    fi
  fi
fi

# MongoDB
if echo "$DB_URL" | grep -qi 'mongo' || grep -qiE 'mongo' docker-compose.yml 2>/dev/null; then
  if command -v mongosh &>/dev/null; then
    mongosh --eval "db.runCommand({ping:1})" --quiet 2>/dev/null && \
      echo "  MongoDB: responding" || \
      echo "FINDING: MongoDB not responding"
  fi
fi

# SQLite - just check the file exists and is valid
for envfile in .env .env.local .env.production; do
  SQLITE_PATH=$(grep -E '(DATABASE_URL|DB_PATH).*sqlite' "$envfile" 2>/dev/null | grep -oE '/[^ "]+\.db' | head -1)
  if [ -n "$SQLITE_PATH" ]; then
    if [ -f "$SQLITE_PATH" ]; then
      if command -v sqlite3 &>/dev/null; then
        INTEGRITY=$(sqlite3 "$SQLITE_PATH" "PRAGMA integrity_check;" 2>/dev/null)
        if [ "$INTEGRITY" = "ok" ]; then
          TABLE_COUNT=$(sqlite3 "$SQLITE_PATH" "SELECT count(*) FROM sqlite_master WHERE type='table';" 2>/dev/null)
          echo "  SQLite ($SQLITE_PATH): OK, $TABLE_COUNT tables"
        else
          echo "FINDING: SQLite database at $SQLITE_PATH failed integrity check"
        fi
      else
        echo "  SQLite file exists at $SQLITE_PATH (sqlite3 not available for validation)"
      fi
    else
      echo "FINDING: SQLite database expected at $SQLITE_PATH but file does not exist"
    fi
  fi
done
```

## Step 5: Docker Compose Full Validation

If docker-compose exists, do a comprehensive check beyond just container status.

```bash
if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ] || [ -f compose.yml ] || [ -f compose.yaml ]; then
  if command -v docker &>/dev/null; then
    COMPOSE_FILE=$(ls docker-compose.yml docker-compose.yaml compose.yml compose.yaml 2>/dev/null | head -1)

    echo "=== Docker Compose validation ==="

    # Config validation
    if command -v docker-compose &>/dev/null; then
      docker-compose -f "$COMPOSE_FILE" config --quiet 2>&1 && \
        echo "  Compose file syntax: valid" || \
        echo "FINDING: Compose file has syntax errors"
    elif docker compose version &>/dev/null 2>&1; then
      docker compose -f "$COMPOSE_FILE" config --quiet 2>&1 && \
        echo "  Compose file syntax: valid" || \
        echo "FINDING: Compose file has syntax errors"
    fi

    # Volume mounts - check host paths exist
    grep -E '^\s+- \.?/' "$COMPOSE_FILE" | grep ':' | while read mount; do
      HOST_PATH=$(echo "$mount" | sed 's/^ *- //' | cut -d: -f1)
      if [ ! -e "$HOST_PATH" ]; then
        echo "FINDING: Volume mount host path does not exist: $HOST_PATH"
      fi
    done

    # Network connectivity between containers
    echo "  Container count: $(docker ps --filter "label=com.docker.compose.project" --format '{{.Names}}' 2>/dev/null | wc -l)"

    # Check restart policies
    docker ps --format "{{.Names}} {{.Status}}" 2>/dev/null | while read name status; do
      RESTARTS=$(echo "$status" | grep -oE 'Restarting' || true)
      if [ -n "$RESTARTS" ]; then
        echo "FINDING: Container $name is in restart loop"
      fi
    done

    # Resource usage summary
    if docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | head -10; then
      true
    fi
  fi
fi
```

## Step 6: Environment Variable Validation

Check that required env vars are set (never print secret values).

```bash
echo "=== Environment variable validation ==="

# Discover required variables from the project
REQUIRED_VARS=""

# From .env.example or .env.template
for template in .env.example .env.template .env.sample; do
  if [ -f "$template" ]; then
    echo "  Checking against $template"
    grep -E '^[A-Z_]+=' "$template" | cut -d= -f1 | while read var; do
      # Check if set in actual .env or environment
      if grep -q "^${var}=" .env 2>/dev/null || [ -n "${!var}" ]; then
        echo "    $var: SET"
      else
        echo "FINDING: Required variable $var (from $template) is not set"
      fi
    done
  fi
done

# From docker-compose environment sections
if [ -f docker-compose.yml ]; then
  grep -A 20 'environment:' docker-compose.yml 2>/dev/null | grep -E '^\s+- [A-Z]' | sed 's/.*- //' | cut -d= -f1 | sort -u | while read var; do
    if [ -n "$var" ] && ! grep -q "^${var}=" .env 2>/dev/null; then
      echo "  Note: $var defined in docker-compose but not in .env (may use compose default)"
    fi
  done
fi
```

## Output Format

Produce a structured summary. Use `FINDING:` prefix for all issues so Phase 10 can parse them.

```
RUNTIME HEALTH CHECK
────────────────────
Services Discovered: 3 (from docker-compose.yml)
Ports Detected:      8000, 5432, 6379

Docker:
  web:      RUNNING (Up 2 hours)
  db:       RUNNING (Up 2 hours, healthy)
  redis:    RUNNING (Up 2 hours)

Database:
  PostgreSQL (localhost:5432): accepting connections
  Redis: responding (PONG)

Health Endpoints:
  http://localhost:8000/health -> 200 OK

Environment:
  DATABASE_URL: SET
  SECRET_KEY:   SET
  API_KEY:      NOT SET

FINDINGS: 1
  - FINDING: Required variable API_KEY (from .env.example) is not set
```

## Exit Criteria

- **PASS**: All discovered services running, all databases reachable, all required env vars set
- **WARN**: Some optional services not running or non-critical env vars missing
- **FAIL**: Expected services not running, database unreachable, or critical env vars missing
