# Phase H: Holistic Cross-Component Analysis

> **Model**: `opus` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only analysis; fixes go to Phase 10)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Grep`, `Glob`, `Read`, `Bash` for cross-component analysis. Parallelize with Phases 7, 5 (after Discovery).

Analyze the codebase as an interconnected system. Map dependencies, trace data flows, detect configuration sprawl, and identify cross-component contract violations.

---

## Step 1: Import & Dependency Mapping

Build a concrete dependency graph showing which modules depend on which.

### 1a. Collect All Imports

```bash
# Python imports
grep -rn "^from .* import\|^import " --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|__pycache__\|node_modules" \
  | sort > /tmp/phase-h-py-imports.txt

# JavaScript/TypeScript imports
grep -rn "require(\|import .* from " --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" "$PROJECT_ROOT" \
  | grep -v "node_modules\|.snapshots\|dist\|build" \
  | sort > /tmp/phase-h-js-imports.txt

# Go imports
grep -rn '"[^"]*"' --include="*.go" "$PROJECT_ROOT" \
  | grep -v vendor\|.snapshots \
  | sort > /tmp/phase-h-go-imports.txt

# Rust use statements
grep -rn "^use \|^pub use " --include="*.rs" "$PROJECT_ROOT" \
  | grep -v target\|.snapshots \
  | sort > /tmp/phase-h-rs-imports.txt

# Shell script sourcing
grep -rn "source \|^\. " --include="*.sh" "$PROJECT_ROOT" \
  | grep -v .snapshots \
  | sort > /tmp/phase-h-sh-sources.txt
```

### 1b. Detect Circular Imports

```bash
# Python: find pairs where A imports B and B imports A
python3 -c "
import re, sys, pathlib, collections

imports = collections.defaultdict(set)
for line in open('/tmp/phase-h-py-imports.txt'):
    match = re.match(r'(.+?\.py):\d+:(from (\S+) import|import (\S+))', line)
    if match:
        src = match.group(1)
        mod = match.group(3) or match.group(4)
        if mod:
            imports[src].add(mod.split('.')[0])

# Check for cycles (simplified: direct A<->B)
for src, deps in imports.items():
    src_mod = pathlib.Path(src).stem
    for dep in deps:
        for other_src, other_deps in imports.items():
            if pathlib.Path(other_src).stem == dep and src_mod in other_deps:
                print(f'CIRCULAR: {src} <-> {other_src}')
" 2>/dev/null || true
```

### 1c. Find Unused Exports

```bash
# Python: find defined functions/classes never imported elsewhere
grep -rn "^def \|^class " --include="*.py" "$PROJECT_ROOT" \
  | grep -v test\|.venv\|.snapshots\|__pycache__ \
  | while IFS=: read -r file line defn; do
    name=$(echo "$defn" | sed 's/^def \|^class //' | sed 's/[(:].*//')
    # Check if this name is imported or referenced elsewhere
    count=$(grep -rn "$name" --include="*.py" "$PROJECT_ROOT" \
      | grep -v ".venv\|.snapshots\|__pycache__\|$file" | wc -l)
    if [ "$count" -eq 0 ]; then
      echo "UNUSED: $file:$line $name"
    fi
  done 2>/dev/null | head -50
```

Report: List all import relationships, flag circular imports and unused exports.

---

## Step 2: Shared Config Detection

Find configuration files and detect sprawl (same setting defined in multiple places).

### 2a. Locate All Config Sources

```bash
# Find config files
find "$PROJECT_ROOT" -type f \( \
  -name "*.env" -o -name "*.env.*" -o -name "*.ini" -o -name "*.cfg" -o \
  -name "*.toml" -o -name "*.yaml" -o -name "*.yml" -o -name "*.conf" -o \
  -name "*.json" -o -name "config.*" -o -name "settings.*" \
\) | grep -v "node_modules\|.venv\|.snapshots\|__pycache__\|.git/" | sort

# Find hardcoded config in source (env var reads)
grep -rn "os\.environ\|os\.getenv\|process\.env\.\|env::var\|viper\.Get" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.rs" \
  "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots" | sort
```

### 2b. Detect Config Sprawl

```bash
# Find variables/settings defined in multiple config files
# Extract key=value or KEY: value patterns from all config files
find "$PROJECT_ROOT" -type f \( -name "*.env" -o -name "*.env.*" -o -name "*.ini" -o -name "*.conf" \) \
  -not -path "*/.snapshots/*" -not -path "*/.venv/*" -not -path "*/.git/*" \
  -exec grep -Hn "^[A-Z_]*=" {} \; 2>/dev/null \
  | awk -F= '{print $1}' | awk -F: '{key=$NF; file=$1; keys[key]=keys[key] " " file}' \
  END '{for (k in keys) {n=split(keys[k], arr, " "); if (n > 1) print "SPRAWL:", k, "defined in", n, "files:", keys[k]}}'

# Check for port/host/path constants defined in multiple source files
for pattern in "PORT\s*=" "HOST\s*=" "DATABASE\s*=" "DB_PATH\s*=" "API_URL\s*="; do
  hits=$(grep -rn "$pattern" --include="*.py" --include="*.js" --include="*.ts" --include="*.sh" \
    "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots\|test" | wc -l)
  if [ "$hits" -gt 1 ]; then
    echo "CONFIG SPRAWL: '$pattern' defined in $hits locations:"
    grep -rn "$pattern" --include="*.py" --include="*.js" --include="*.ts" --include="*.sh" \
      "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots\|test"
  fi
done
```

### 2c. Cross-Language Config Consistency

```bash
# Find all port references and verify consistency
echo "=== Port definitions ==="
grep -rn "port\s*[:=]\s*[0-9]" --include="*.py" --include="*.js" --include="*.ts" \
  --include="*.yaml" --include="*.yml" --include="*.toml" --include="*.env" --include="*.sh" \
  --include="*.service" "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots\|test" | sort

# Find all database path references and verify consistency
echo "=== Database paths ==="
grep -rn "\.db\b\|\.sqlite\|database.*=\|DB_PATH\|DB_FILE\|DATABASE_URL" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.sh" --include="*.env" \
  --include="*.toml" --include="*.yaml" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots\|test\|__pycache__" | sort
```

Report: List each setting, all locations where it appears, and flag mismatches.

---

## Step 3: Data Flow Tracing

Identify where data enters, where it is stored, and where it exits. Flag flows that bypass validation.

### 3a. Map Entry Points

```bash
# API endpoints (Python Flask/FastAPI/Django)
grep -rn "@app\.route\|@router\.\|@api_view\|path(" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test" | sort

# API endpoints (Node.js Express/Fastify)
grep -rn "app\.\(get\|post\|put\|delete\|patch\)\|router\.\(get\|post\|put\|delete\|patch\)" \
  --include="*.js" --include="*.ts" "$PROJECT_ROOT" | grep -v "node_modules\|.snapshots\|test" | sort

# CLI entry points
grep -rn "argparse\|click\.command\|typer\.\|clap::Parser\|flag\.Parse\|cobra" \
  --include="*.py" --include="*.go" --include="*.rs" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|vendor" | sort

# File reads (data ingestion)
grep -rn "open(\|read_file\|readFileSync\|os\.ReadFile\|fs::read" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.rs" \
  "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots\|test" | sort
```

### 3b. Map Storage Points

```bash
# Database writes
grep -rn "\.execute\|\.commit\|\.insert\|\.update\|\.save\|\.create\|INSERT INTO\|UPDATE .* SET" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots\|test" | sort

# File writes
grep -rn "open(.*['\"]w\|write(\|writeFileSync\|os\.WriteFile\|fs::write" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.rs" \
  "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots\|test" | sort

# Environment/state writes
grep -rn "os\.environ\[.*\]\s*=\|process\.env\.\S*\s*=\|os\.Setenv" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots" | sort
```

### 3c. Map Exit Points

```bash
# API responses
grep -rn "return.*jsonify\|return.*Response\|res\.json\|res\.send\|json\.NewEncoder\|HttpResponse" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots\|test" | sort

# Logging (potential data leakage)
grep -rn "logger\.\|logging\.\|console\.log\|log\.\(Print\|Info\|Warn\|Error\)" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots\|test" | wc -l
# Count only — read selectively if count is high
```

### 3d. Flag Unvalidated Flows

```bash
# API endpoints that read request data without validation
# Python: request.form/json/args without schema validation
grep -rn "request\.\(form\|json\|args\|data\)\[" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test" | while IFS=: read -r file line rest; do
    # Check if the same function has validation (marshmallow, pydantic, wtforms)
    func_start=$(grep -n "^def \|^async def " "$file" | awk -F: -v ln="$line" '$1 < ln {last=$1} END {print last}')
    has_validation=$(sed -n "${func_start},${line}p" "$file" | grep -c "validate\|schema\|Schema\|BaseModel\|Form")
    if [ "$has_validation" -eq 0 ]; then
      echo "UNVALIDATED: $file:$line $rest"
    fi
  done 2>/dev/null

# Node.js: req.body/params/query without validation
grep -rn "req\.\(body\|params\|query\)\." --include="*.js" --include="*.ts" "$PROJECT_ROOT" \
  | grep -v "node_modules\|.snapshots\|test" | head -30
```

Report: List each data flow (entry -> storage -> exit) and flag unvalidated paths.

---

## Step 4: Cross-Component Issues

### 4a. Hardcoded Paths

```bash
# Absolute paths that should be configurable
grep -rn "\"\/opt\/\|\"\/var\/\|\"\/etc\/\|\"\/srv\/\|\"\/home\/" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.rs" \
  --include="*.sh" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots\|test\|__pycache__\|.git/" \
  | grep -v "# \|// \|/\*" | sort
```

### 4b. Version Mismatches

```bash
# Check for version strings defined in multiple places
grep -rn "version\s*[:=]\s*['\"][0-9]" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.toml" \
  --include="*.json" --include="*.yaml" --include="*.yml" --include="*.cfg" \
  "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots\|.git/" | sort

# Flag if multiple different version values exist
grep -rn "version\s*[:=]\s*['\"][0-9]" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.toml" \
  --include="*.json" --include="*.yaml" --include="*.yml" \
  "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots\|.git/" \
  | grep -oP "['\"][0-9]+\.[0-9]+[^'\"]*['\"]" | sort -u | wc -l
# If count > 1, versions are out of sync
```

### 4c. Dead Code and Unused Exports

```bash
# Python: functions defined but never called (excluding test files)
grep -rn "^def " --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test\|__pycache__" \
  | while IFS=: read -r file line defn; do
    name=$(echo "$defn" | sed 's/^def //' | sed 's/(.*//')
    # Skip dunder methods and private methods
    echo "$name" | grep -q "^__\|^_" && continue
    refs=$(grep -rn "\b${name}\b" --include="*.py" "$PROJECT_ROOT" \
      | grep -v ".venv\|.snapshots\|__pycache__" | grep -v "^$file:$line:" | wc -l)
    if [ "$refs" -eq 0 ]; then
      echo "DEAD CODE: $file:$line def $name()"
    fi
  done 2>/dev/null | head -30

# JavaScript: exported functions never imported elsewhere
grep -rn "^export \(function\|const\|class\) " --include="*.js" --include="*.ts" "$PROJECT_ROOT" \
  | grep -v "node_modules\|.snapshots\|dist\|build\|test" \
  | while IFS=: read -r file line defn; do
    name=$(echo "$defn" | sed 's/^export \(function\|const\|class\) //' | sed 's/[( {=].*//')
    refs=$(grep -rn "\b${name}\b" --include="*.js" --include="*.ts" "$PROJECT_ROOT" \
      | grep -v "node_modules\|.snapshots\|dist\|build" | grep -v "^$file:" | wc -l)
    if [ "$refs" -eq 0 ]; then
      echo "UNUSED EXPORT: $file:$line $name"
    fi
  done 2>/dev/null | head -30
```

---

## Step 5: Integration Surface Audit

Verify that inter-component interfaces agree on their contracts.

### 5a. API Contract Verification

```bash
# List all API route definitions with their HTTP methods and paths
echo "=== Backend API Routes ==="
grep -rn "@app\.route\|@router\.\(get\|post\|put\|delete\|patch\)" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test" | sort

# List all frontend API calls with their URLs and methods
echo "=== Frontend API Calls ==="
grep -rn "fetch(\|axios\.\|http\.\|\.get(\|\.post(\|\.put(\|\.delete(" \
  --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" "$PROJECT_ROOT" \
  | grep -v "node_modules\|.snapshots\|test" | sort

# Cross-reference: extract URL paths from both sides and diff
echo "=== Backend paths ==="
grep -rn "@app\.route\|@router\." --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test" \
  | grep -oP "['\"]\/[^'\"]*['\"]" | sort -u > /tmp/phase-h-backend-routes.txt

echo "=== Frontend paths ==="
grep -rn "fetch(\|axios\." --include="*.js" --include="*.ts" "$PROJECT_ROOT" \
  | grep -v "node_modules\|.snapshots\|test" \
  | grep -oP "['\"]\/api[^'\"]*['\"]" | sort -u > /tmp/phase-h-frontend-routes.txt

# Show routes called by frontend but not defined in backend
comm -23 /tmp/phase-h-frontend-routes.txt /tmp/phase-h-backend-routes.txt 2>/dev/null
```

### 5b. Shell Script Interface Audit

```bash
# Find scripts that call other scripts
grep -rn "bash \|sh \|\.\/" --include="*.sh" "$PROJECT_ROOT" \
  | grep -v ".snapshots\|.git/" | sort

# Check that called scripts actually exist
grep -rn "source \|^\. \|bash \|sh " --include="*.sh" "$PROJECT_ROOT" \
  | grep -v ".snapshots\|.git/" \
  | grep -oP "[\w./-]+\.sh" | sort -u | while read -r script; do
    found=$(find "$PROJECT_ROOT" -name "$(basename "$script")" -type f 2>/dev/null | head -1)
    if [ -z "$found" ]; then
      echo "MISSING SCRIPT: $script"
    fi
  done
```

### 5c. Shared File Interface Audit

```bash
# Find files written by one component and read by another
# Identify file paths mentioned in write operations
echo "=== Write targets ==="
grep -rn "open(.*['\"]w\|write_text\|with open" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test\|__pycache__" \
  | grep -oP "['\"][^'\"]*\.\(txt\|csv\|json\|log\|idx\|dat\|pid\)['\"]" | sort -u

# Identify file paths mentioned in read operations
echo "=== Read sources ==="
grep -rn "open(.*['\"]r\|read_text\|with open" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test\|__pycache__" \
  | grep -oP "['\"][^'\"]*\.\(txt\|csv\|json\|log\|idx\|dat\|pid\)['\"]" | sort -u
```

---

## Output Format

Structure all findings for Phase 10 consumption:

```
===============================================================
  PHASE H: HOLISTIC CROSS-COMPONENT ANALYSIS
===============================================================

--- DEPENDENCY MAP ---
Total modules analyzed: N
Circular imports:       N (list each pair)
Unused exports:         N (list each)

--- CONFIGURATION ---
Config files found:     N
Config sprawl:          N settings defined in multiple places
Cross-language mismatches: N (list each)

--- DATA FLOWS ---
Entry points:           N (API: X, CLI: Y, File: Z)
Storage points:         N (DB: X, File: Y)
Exit points:            N (API: X, Log: Y, File: Z)
Unvalidated flows:      N (list each)

--- CROSS-COMPONENT ISSUES ---
Issue 1:
  Type:       [circular-import | config-sprawl | hardcoded-path |
               version-mismatch | dead-code | contract-violation |
               unvalidated-flow | missing-dependency]
  Severity:   [CRITICAL | HIGH | MEDIUM | LOW]
  Location:   file:line
  Related:    [other files affected]
  Detail:     [description]
  Fix:        [suggested fix]

--- INTEGRATION SURFACES ---
API routes defined:     N
API routes consumed:    N
Orphaned routes:        N (defined but never called)
Missing routes:         N (called but not defined)
Script interfaces:      N
Missing scripts:        N (referenced but not found)

--- SUMMARY VERDICT ---
Status: [PASS | FAIL]
Cross-component issues: N total (X critical, Y high, Z medium)
===============================================================
```

## Autonomous Fix Protocol

When fixing cross-component issues:

1. **Fix the root cause first** — do not patch symptoms
2. **Update all affected components** — if an API changes, update callers too
3. **Verify the full flow** — not just the changed file
4. **Add comments** at cross-component boundaries explaining the dependency

## Integration with Other Phases

- **Phase 1 (Discovery)**: Provides file inventory and project type
- **Phase 5 (Security)**: Security issues often span components; Phase H maps the full attack surface
- **Phase 7 (Quality)**: Code quality at the single-file level; Phase H adds the cross-component dimension
- **Phase 10 (Fix)**: Receives structured issue list from Phase H for implementation

## Checklist

```
[ ] Import/dependency map built for all source files
[ ] Circular imports checked and flagged
[ ] Unused exports identified
[ ] Config files enumerated and cross-referenced
[ ] Config sprawl (duplicate settings) detected
[ ] Cross-language config consistency verified (ports, paths, DB)
[ ] Data entry points mapped (API, CLI, file reads)
[ ] Data storage points mapped (DB, file writes)
[ ] Data exit points mapped (API responses, logs, file writes)
[ ] Unvalidated data flows flagged
[ ] Hardcoded paths detected
[ ] Version string consistency verified
[ ] Dead code identified
[ ] API contracts verified (backend routes vs frontend calls)
[ ] Script dependencies verified (called scripts exist)
[ ] Shared file interfaces audited
[ ] All issues structured for Phase 10
```
