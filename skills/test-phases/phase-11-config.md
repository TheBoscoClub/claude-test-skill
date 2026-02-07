# Phase 11: Configuration Audit

> **Model**: `sonnet` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Read`, `Glob`, `Grep` for config analysis. Parallelize with other Tier 3 phases.

Validate project configuration files.

## Files to Check

| File | Purpose |
|------|---------|
| `.env` / `.env.example` | Environment variables |
| `pyproject.toml` | Python project config |
| `package.json` | Node.js project config |
| `docker-compose.yml` | Container orchestration |
| `Dockerfile` | Container build |
| `.github/workflows/*.yml` | CI/CD pipelines |
| `Makefile` | Build automation |

## Execution Steps

### 1. Environment Variables

```bash
# Check .env.example exists
if [ -f ".env.example" ]; then
  echo "✅ .env.example exists"

  # Check all example vars are documented
  if [ -f ".env" ]; then
    # Find vars in .env not in .env.example
    comm -23 <(grep -oE "^[A-Z_]+=" .env | sort) \
             <(grep -oE "^[A-Z_]+=" .env.example | sort)
  fi
else
  echo "⚠️ Missing .env.example"
fi

# Check .env is in .gitignore
grep -q "\.env" .gitignore && echo "✅ .env in .gitignore"
```

### 2. Python Configuration

```bash
if [ -f "pyproject.toml" ]; then
  # Check required sections
  grep -q "\[project\]" pyproject.toml && echo "✅ [project] section"
  grep -q "\[build-system\]" pyproject.toml && echo "✅ [build-system] section"

  # Check Python version specified
  grep -q "python_requires\|requires-python" pyproject.toml
fi
```

### 3. Node.js Configuration

```bash
if [ -f "package.json" ]; then
  # Check required fields
  jq -e '.name' package.json >/dev/null && echo "✅ name field"
  jq -e '.version' package.json >/dev/null && echo "✅ version field"
  jq -e '.scripts.test' package.json >/dev/null && echo "✅ test script"

  # Check engines specified
  jq -e '.engines.node' package.json >/dev/null && echo "✅ node version"
fi
```

### 4. Docker Configuration

```bash
if [ -f "Dockerfile" ]; then
  # Check best practices
  grep -q "^FROM.*:.*" Dockerfile && echo "✅ Pinned base image"
  grep -q "^USER" Dockerfile && echo "✅ Non-root user"
  grep -q "HEALTHCHECK" Dockerfile && echo "⚠️ No HEALTHCHECK"
fi
```

### 5. CI/CD Configuration

```bash
if [ -d ".github/workflows" ]; then
  for f in .github/workflows/*.yml; do
    # Validate YAML syntax
    python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null
  done
fi
```

## Output Format

```
CONFIGURATION AUDIT
───────────────────

Environment:
  ✅ .env.example exists
  ✅ .env in .gitignore
  ⚠️ 2 undocumented vars in .env

Python (pyproject.toml):
  ✅ Valid TOML
  ✅ Python version specified
  ⚠️ Missing [tool.pytest] section

Docker:
  ✅ Pinned base image
  ❌ Running as root (security risk)
  ⚠️ No HEALTHCHECK defined

CI/CD:
  ✅ 2 workflow files valid
  ⚠️ No caching configured
```
