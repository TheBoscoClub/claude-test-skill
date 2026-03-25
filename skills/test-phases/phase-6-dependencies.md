# Phase 6: Dependency Health

> **Model**: `sonnet` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for audit commands. Use `WebSearch` to look up CVE details for flagged vulnerabilities. Parallelize with other Tier 3 phases. Includes cross-component import mapping, circular import detection, and unused export analysis.

Detect all dependency ecosystems present in the project, audit each for outdated packages, known vulnerabilities, dependency conflicts, and license compliance. Produce a structured severity-classified report for Phase 10 consumption.

---

## Step 1: Detect Ecosystems

Identify which package ecosystems are present. Only run checks for detected ecosystems.

```bash
echo "=== Ecosystem detection ==="
ECOSYSTEMS=""

[ -f requirements.txt ] || [ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ] || [ -f Pipfile ] && ECOSYSTEMS="$ECOSYSTEMS python"
[ -f package.json ] && ECOSYSTEMS="$ECOSYSTEMS node"
[ -f go.mod ] && ECOSYSTEMS="$ECOSYSTEMS go"
[ -f Cargo.toml ] && ECOSYSTEMS="$ECOSYSTEMS rust"
[ -f Gemfile ] && ECOSYSTEMS="$ECOSYSTEMS ruby"
[ -f composer.json ] && ECOSYSTEMS="$ECOSYSTEMS php"
[ -f pom.xml ] || [ -f build.gradle ] || [ -f build.gradle.kts ] && ECOSYSTEMS="$ECOSYSTEMS java"

if [ -z "$ECOSYSTEMS" ]; then
  echo "No dependency ecosystems detected. Skipping Phase 6."
  exit 0
fi

echo "Detected ecosystems:$ECOSYSTEMS"
```

## Step 2: Python Dependencies

Run only if `python` is in `$ECOSYSTEMS`.

### 2a. Inventory

```bash
echo "=== Python dependency inventory ==="

# Determine the dependency source
if [ -f pyproject.toml ]; then
  echo "Source: pyproject.toml"
  # Count declared dependencies
  grep -cE '^\s+"[a-zA-Z]' pyproject.toml 2>/dev/null || \
  grep -cE '^\s+[a-zA-Z].*[>=<]' pyproject.toml 2>/dev/null || echo "(could not parse count)"
elif [ -f requirements.txt ]; then
  echo "Source: requirements.txt"
  grep -cvE '^\s*#|^\s*$' requirements.txt
fi

# Separate dev dependencies if distinguishable
if [ -f requirements-dev.txt ]; then
  echo "Dev dependencies (requirements-dev.txt): $(grep -cvE '^\s*#|^\s*$' requirements-dev.txt)"
fi
if [ -f pyproject.toml ]; then
  grep -A 50 '\[project.optional-dependencies\]' pyproject.toml 2>/dev/null | grep -E '^\s+"' | head -20
fi

# Installed packages count
if command -v pip &>/dev/null; then
  echo "Installed packages: $(pip list --format=columns 2>/dev/null | tail -n +3 | wc -l)"
fi
```

### 2b. Outdated Packages

```bash
if command -v pip &>/dev/null; then
  echo "=== Python outdated packages ==="
  pip list --outdated --format=columns 2>/dev/null | tee /tmp/phase6-python-outdated.txt

  # Classify severity
  while IFS= read -r line; do
    PKG=$(echo "$line" | awk '{print $1}')
    CURRENT=$(echo "$line" | awk '{print $2}')
    LATEST=$(echo "$line" | awk '{print $3}')
    # Major version change = MEDIUM, minor/patch = LOW
    CUR_MAJOR=$(echo "$CURRENT" | cut -d. -f1)
    LAT_MAJOR=$(echo "$LATEST" | cut -d. -f1)
    if [ "$CUR_MAJOR" != "$LAT_MAJOR" ]; then
      echo "FINDING [MEDIUM]: $PKG $CURRENT -> $LATEST (major version behind)"
    else
      echo "FINDING [LOW]: $PKG $CURRENT -> $LATEST (minor/patch update available)"
    fi
  done < <(tail -n +3 /tmp/phase6-python-outdated.txt 2>/dev/null | head -50)
fi
```

### 2c. Vulnerability Scan

```bash
echo "=== Python vulnerability scan ==="
if command -v pip-audit &>/dev/null; then
  pip-audit --progress-spinner=off --desc on 2>&1 | tee /tmp/phase6-python-vulns.txt
  EXIT_CODE=${PIPESTATUS[0]}

  if [ $EXIT_CODE -ne 0 ]; then
    # Parse vulnerabilities and classify
    grep -E '^[a-zA-Z]' /tmp/phase6-python-vulns.txt | while IFS= read -r line; do
      PKG=$(echo "$line" | awk '{print $1}')
      CVE=$(echo "$line" | grep -oE 'CVE-[0-9]+-[0-9]+' | head -1)
      FIX=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
      if [ -n "$CVE" ]; then
        echo "FINDING [HIGH]: $PKG has known vulnerability $CVE (fix available: $FIX)"
      else
        echo "FINDING [HIGH]: $PKG has known vulnerability (see pip-audit output)"
      fi
    done

    # Check fix availability
    echo ""
    echo "--- Auto-fix dry run ---"
    pip-audit --fix --dry-run 2>&1 | head -20
  else
    echo "No known vulnerabilities found."
  fi
elif command -v safety &>/dev/null; then
  echo "(pip-audit not available, falling back to safety)"
  safety check --full-report 2>&1 | head -50
else
  echo "FINDING [MEDIUM]: Neither pip-audit nor safety installed -- cannot scan Python vulnerabilities"
fi
```

### 2d. Dependency Conflicts

```bash
if command -v pip &>/dev/null; then
  echo "=== Python dependency conflicts ==="
  CONFLICTS=$(pip check 2>&1)
  if [ $? -ne 0 ]; then
    echo "$CONFLICTS" | while IFS= read -r line; do
      echo "FINDING [MEDIUM]: Dependency conflict: $line"
    done
  else
    echo "No dependency conflicts."
  fi
fi
```

### 2e. License Check

```bash
echo "=== Python license check ==="
if command -v pip-licenses &>/dev/null; then
  pip-licenses --format=table --order=license 2>/dev/null | head -40
  # Flag copyleft licenses in non-GPL projects
  COPYLEFT=$(pip-licenses --format=csv 2>/dev/null | grep -iE 'GPL|AGPL|LGPL|SSPL|EUPL' | grep -viE 'BSD.*GPL')
  if [ -n "$COPYLEFT" ]; then
    echo "$COPYLEFT" | while IFS= read -r line; do
      echo "FINDING [LOW]: Copyleft license detected: $line"
    done
  fi
else
  echo "(pip-licenses not installed -- skipping license check)"
fi
```

## Step 3: Node.js Dependencies

Run only if `node` is in `$ECOSYSTEMS`.

### 3a. Inventory

```bash
echo "=== Node.js dependency inventory ==="
if [ -f package.json ]; then
  PROD_DEPS=$(grep -c '"' package.json 2>/dev/null | head -1)  # rough count
  # More precise count
  if command -v node &>/dev/null; then
    node -e "
      const pkg = require('./package.json');
      const deps = Object.keys(pkg.dependencies || {});
      const devDeps = Object.keys(pkg.devDependencies || {});
      console.log('Production dependencies:', deps.length);
      console.log('Dev dependencies:', devDeps.length);
    " 2>/dev/null
  fi

  # Check lock file presence
  [ -f package-lock.json ] && echo "Lock file: package-lock.json"
  [ -f yarn.lock ] && echo "Lock file: yarn.lock"
  [ -f pnpm-lock.yaml ] && echo "Lock file: pnpm-lock.yaml"
  [ ! -f package-lock.json ] && [ ! -f yarn.lock ] && [ ! -f pnpm-lock.yaml ] && \
    echo "FINDING [MEDIUM]: No lock file found -- builds are not reproducible"
fi
```

### 3b. Outdated Packages

```bash
if command -v npm &>/dev/null && [ -f package.json ]; then
  echo "=== Node.js outdated packages ==="
  npm outdated 2>/dev/null | tee /tmp/phase6-node-outdated.txt

  # Classify: wanted vs latest differences indicate major version lag
  tail -n +2 /tmp/phase6-node-outdated.txt 2>/dev/null | while IFS= read -r line; do
    PKG=$(echo "$line" | awk '{print $1}')
    CURRENT=$(echo "$line" | awk '{print $2}')
    WANTED=$(echo "$line" | awk '{print $3}')
    LATEST=$(echo "$line" | awk '{print $4}')
    if [ "$WANTED" != "$LATEST" ]; then
      echo "FINDING [MEDIUM]: $PKG $CURRENT -> $LATEST (major version behind, wanted=$WANTED)"
    elif [ "$CURRENT" != "$WANTED" ]; then
      echo "FINDING [LOW]: $PKG $CURRENT -> $WANTED (minor/patch update)"
    fi
  done
fi
```

### 3c. Vulnerability Scan

```bash
if command -v npm &>/dev/null && [ -f package.json ]; then
  echo "=== Node.js vulnerability scan ==="
  AUDIT_OUTPUT=$(npm audit --json 2>/dev/null)
  AUDIT_EXIT=$?

  if [ $AUDIT_EXIT -ne 0 ] && command -v node &>/dev/null; then
    # Parse JSON audit output for structured findings
    echo "$AUDIT_OUTPUT" | node -e "
      const data = require('fs').readFileSync('/dev/stdin', 'utf8');
      try {
        const audit = JSON.parse(data);
        const vulns = audit.vulnerabilities || {};
        for (const [name, info] of Object.entries(vulns)) {
          const sev = info.severity.toUpperCase();
          const mapped = sev === 'CRITICAL' ? 'CRITICAL' : sev === 'HIGH' ? 'HIGH' : sev === 'MODERATE' ? 'MEDIUM' : 'LOW';
          console.log('FINDING [' + mapped + ']: ' + name + ' (' + info.severity + ') - ' + (info.via?.[0]?.title || 'see npm audit'));
        }
      } catch(e) { console.log('Could not parse npm audit JSON'); }
    " 2>/dev/null || npm audit 2>/dev/null | head -40
  else
    echo "No known vulnerabilities found."
  fi

  # Check fix availability
  echo ""
  echo "--- Auto-fix dry run ---"
  npm audit fix --dry-run 2>&1 | tail -5
fi
```

### 3d. License Check

```bash
echo "=== Node.js license check ==="
if command -v npx &>/dev/null && [ -f package.json ]; then
  npx --yes license-checker --summary 2>/dev/null | head -20
  COPYLEFT=$(npx --yes license-checker --csv 2>/dev/null | grep -iE 'GPL|AGPL|SSPL' | grep -viE 'BSD.*GPL')
  if [ -n "$COPYLEFT" ]; then
    echo "$COPYLEFT" | while IFS= read -r line; do
      echo "FINDING [LOW]: Copyleft license detected: $line"
    done
  fi
else
  echo "(npx not available -- skipping Node.js license check)"
fi
```

## Step 4: Go Dependencies

Run only if `go` is in `$ECOSYSTEMS`.

```bash
echo "=== Go dependency analysis ==="
if [ -f go.mod ]; then
  # Inventory
  echo "Direct dependencies: $(grep -c '^	' go.mod 2>/dev/null || echo 'unknown')"
  [ ! -f go.sum ] && echo "FINDING [MEDIUM]: go.sum missing -- run 'go mod tidy'"

  # Outdated
  if command -v go &>/dev/null; then
    echo "--- Outdated modules ---"
    go list -m -u all 2>/dev/null | grep '\[' | while IFS= read -r line; do
      MOD=$(echo "$line" | awk '{print $1}')
      CURRENT=$(echo "$line" | awk '{print $2}')
      LATEST=$(echo "$line" | grep -oE '\[.*\]' | tr -d '[]')
      echo "FINDING [LOW]: $MOD $CURRENT -> $LATEST"
    done

    # Vulnerability scan
    if command -v govulncheck &>/dev/null; then
      echo "--- Go vulnerability scan ---"
      govulncheck ./... 2>&1 | tee /tmp/phase6-go-vulns.txt
      grep -E '^Vulnerability' /tmp/phase6-go-vulns.txt | while IFS= read -r line; do
        echo "FINDING [HIGH]: $line"
      done
    else
      echo "FINDING [MEDIUM]: govulncheck not installed -- cannot scan Go vulnerabilities"
    fi

    # Dependency tidiness
    go mod verify 2>&1 | grep -v 'verified' | while IFS= read -r line; do
      echo "FINDING [MEDIUM]: go mod verify: $line"
    done
  fi
fi
```

## Step 5: Rust Dependencies

Run only if `rust` is in `$ECOSYSTEMS`.

```bash
echo "=== Rust dependency analysis ==="
if [ -f Cargo.toml ]; then
  # Inventory
  if command -v cargo &>/dev/null; then
    echo "Dependency tree (depth 1):"
    cargo tree --depth=1 2>/dev/null | head -30

    # Outdated
    if command -v cargo-outdated &>/dev/null || cargo outdated --version &>/dev/null 2>&1; then
      echo "--- Outdated crates ---"
      cargo outdated --root-deps-only 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        CRATE=$(echo "$line" | awk '{print $1}')
        CURRENT=$(echo "$line" | awk '{print $2}')
        LATEST=$(echo "$line" | awk '{print $4}')
        COMPAT=$(echo "$line" | awk '{print $3}')
        if [ "$CURRENT" != "$LATEST" ] && [ "$LATEST" != "---" ]; then
          CUR_MAJOR=$(echo "$CURRENT" | cut -d. -f1)
          LAT_MAJOR=$(echo "$LATEST" | cut -d. -f1)
          if [ "$CUR_MAJOR" != "$LAT_MAJOR" ]; then
            echo "FINDING [MEDIUM]: $CRATE $CURRENT -> $LATEST (major version behind)"
          else
            echo "FINDING [LOW]: $CRATE $CURRENT -> $LATEST"
          fi
        fi
      done
    else
      echo "(cargo-outdated not installed -- skipping outdated check)"
    fi

    # Vulnerability scan
    if command -v cargo-audit &>/dev/null || cargo audit --version &>/dev/null 2>&1; then
      echo "--- Rust vulnerability scan ---"
      cargo audit 2>&1 | tee /tmp/phase6-rust-vulns.txt
      grep -E '^error' /tmp/phase6-rust-vulns.txt | while IFS= read -r line; do
        echo "FINDING [HIGH]: $line"
      done
    else
      echo "FINDING [MEDIUM]: cargo-audit not installed -- cannot scan Rust vulnerabilities"
    fi

    # License check
    if command -v cargo-deny &>/dev/null || cargo deny --version &>/dev/null 2>&1; then
      echo "--- Rust license check ---"
      cargo deny check licenses 2>&1 | grep -E '^(error|warning)' | while IFS= read -r line; do
        echo "FINDING [LOW]: License issue: $line"
      done
    fi
  fi
fi
```

## Step 6: Ruby Dependencies

Run only if `ruby` is in `$ECOSYSTEMS`.

```bash
echo "=== Ruby dependency analysis ==="
if [ -f Gemfile ]; then
  [ ! -f Gemfile.lock ] && echo "FINDING [MEDIUM]: Gemfile.lock missing -- run 'bundle install'"

  if command -v bundle &>/dev/null; then
    echo "--- Outdated gems ---"
    bundle outdated 2>/dev/null | grep -E '^\s+\*' | while IFS= read -r line; do
      echo "FINDING [LOW]: Outdated gem: $line"
    done

    if command -v bundler-audit &>/dev/null || bundle exec bundler-audit --version &>/dev/null 2>&1; then
      echo "--- Ruby vulnerability scan ---"
      bundle exec bundler-audit check --update 2>&1 | grep -E '^(Name|Advisory|Criticality)' | while IFS= read -r line; do
        echo "FINDING [HIGH]: $line"
      done
    else
      echo "(bundler-audit not installed -- skipping Ruby vulnerability scan)"
    fi
  fi
fi
```

## Step 7: Cross-Ecosystem Checks

```bash
echo "=== Cross-ecosystem checks ==="

# Check for pinned vs unpinned dependencies
if [ -f requirements.txt ]; then
  UNPINNED=$(grep -cvE '==|>=|<=|~=|!=|^\s*#|^\s*$' requirements.txt 2>/dev/null)
  if [ "$UNPINNED" -gt 0 ] 2>/dev/null; then
    echo "FINDING [MEDIUM]: $UNPINNED unpinned dependencies in requirements.txt (no version specifier)"
  fi
fi

# Check for .nvmrc / .python-version / rust-toolchain.toml consistency
[ -f .nvmrc ] && echo "Node version pinned: $(cat .nvmrc)"
[ -f .python-version ] && echo "Python version pinned: $(cat .python-version)"
[ -f rust-toolchain.toml ] && echo "Rust toolchain pinned: $(grep channel rust-toolchain.toml 2>/dev/null)"

# Dockerfile dependency alignment
if [ -f Dockerfile ]; then
  echo "--- Dockerfile dependency check ---"
  # Check if Dockerfile copies requirements/package files
  grep -E '^(COPY|ADD).*(requirements|package|go\.(mod|sum)|Cargo)' Dockerfile 2>/dev/null
  # Check for unpinned apt-get/apk/dnf installs
  UNPINNED_SYS=$(grep -E '(apt-get install|apk add|dnf install)' Dockerfile 2>/dev/null | grep -cvE '=[0-9]')
  if [ "$UNPINNED_SYS" -gt 0 ] 2>/dev/null; then
    echo "FINDING [LOW]: Dockerfile has $UNPINNED_SYS unpinned system package installs"
  fi
fi
```

## Cross-Component Dependency Analysis

Every phase must analyze dependencies holistically — not just within individual files but across the entire project. This section is mandatory for all /test audits.

### Import & Dependency Mapping

Build a concrete dependency graph showing which modules depend on which.

```bash
# Python imports
grep -rn "^from .* import\|^import " --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|__pycache__\|node_modules" \
  | sort > /tmp/phase-6-crosscomp-py-imports.txt

# JavaScript/TypeScript imports
grep -rn "require(\|import .* from " --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" "$PROJECT_ROOT" \
  | grep -v "node_modules\|.snapshots\|dist\|build" \
  | sort > /tmp/phase-6-crosscomp-js-imports.txt

# Go imports
grep -rn '"[^"]*"' --include="*.go" "$PROJECT_ROOT" \
  | grep -v vendor\|.snapshots \
  | sort > /tmp/phase-6-crosscomp-go-imports.txt

# Rust use statements
grep -rn "^use \|^pub use " --include="*.rs" "$PROJECT_ROOT" \
  | grep -v target\|.snapshots \
  | sort > /tmp/phase-6-crosscomp-rs-imports.txt

# Shell script sourcing
grep -rn "source \|^\. " --include="*.sh" "$PROJECT_ROOT" \
  | grep -v .snapshots \
  | sort > /tmp/phase-6-crosscomp-sh-sources.txt
```

```bash
# Python: find pairs where A imports B and B imports A
python3 -c "
import re, sys, pathlib, collections

imports = collections.defaultdict(set)
for line in open('/tmp/phase-6-crosscomp-py-imports.txt'):
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

## Severity Classification Reference

| Severity | Criteria | Examples |
|----------|----------|---------|
| **CRITICAL** | Known CVE with public exploit or active exploitation | RCE, auth bypass with PoC |
| **HIGH** | Known CVE, no known exploit yet | pip-audit/npm audit/cargo audit findings |
| **MEDIUM** | Outdated major version, missing lock file, unpinned deps | Major version behind, no Gemfile.lock |
| **LOW** | Outdated minor/patch, copyleft license in permissive project | Minor updates, GPL dependency |

## Checklist

- [ ] Import/dependency map built for all source files
- [ ] Circular imports checked and flagged
- [ ] Unused exports identified

## Output Format

Produce a structured summary. Use `FINDING [SEVERITY]:` prefix for all issues so Phase 10 can parse them.

```
DEPENDENCY HEALTH
─────────────────
Ecosystems Detected: python, node
Total Packages:      45 (Python: 32, Node: 13)

PYTHON:
  Outdated:        8 (2 major, 6 minor/patch)
  Vulnerabilities: 1 HIGH (CVE-2024-XXXXX in requests)
  Conflicts:       0
  Licenses:        All permissive

NODE:
  Outdated:        3 (1 major, 2 minor)
  Vulnerabilities: 2 HIGH, 1 MODERATE
  Lock File:       package-lock.json present
  Licenses:        1 copyleft (GPL) flagged

FINDINGS SUMMARY:
  CRITICAL: 0
  HIGH:     3
  MEDIUM:   2
  LOW:      8
  Total:    13
```

## Exit Criteria

- **PASS**: No CRITICAL or HIGH findings
- **WARN**: HIGH findings exist but have fix versions available
- **FAIL**: CRITICAL findings, or HIGH findings with no fix path
