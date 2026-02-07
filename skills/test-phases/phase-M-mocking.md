# Phase M: Mocking/Sandbox Environment

> **Model**: `haiku` | **Tier**: 0 (Pre-test) | **Modifies Files**: Creates sandbox
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for sandbox setup. Use `KillShell` if sandbox creation hangs.

Set up isolated environment for safe testing.

## Purpose

Create a sandbox that:
- Isolates tests from production data
- Mocks external services
- Provides reproducible test state

## Execution Steps

### 1. Detect Project Type

```bash
if [ -f "package.json" ]; then
  PROJECT_TYPE="node"
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
  PROJECT_TYPE="python"
elif [ -f "go.mod" ]; then
  PROJECT_TYPE="go"
elif [ -f "Cargo.toml" ]; then
  PROJECT_TYPE="rust"
else
  PROJECT_TYPE="unknown"
fi
```

### 2. Create Sandbox Directory

```bash
SANDBOX_DIR="./sandbox-$(date +%s)"
mkdir -p "$SANDBOX_DIR"
```

### 3. Set Test Environment Variables

```bash
export NODE_ENV=test
export FLASK_ENV=testing
export DJANGO_SETTINGS_MODULE=project.settings.test
export GO_ENV=test
export RUST_TEST=1
```

### 4. Mock External Services

Check for docker-compose.test.yml or similar:
```bash
if [ -f "docker-compose.test.yml" ]; then
  docker-compose -f docker-compose.test.yml up -d
fi
```

### 5. Database Mocking

- SQLite in-memory for tests
- Test database with fixtures
- Mock database connections

## Output

Report:
- Sandbox directory path
- Environment variables set
- Mocked services started
- Cleanup command for later
