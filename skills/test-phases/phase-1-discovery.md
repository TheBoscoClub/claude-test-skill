# Phase 1: Discovery

Identify project type, test framework, and testable components.

## Execution Steps

### 1. Detect Project Type

| File | Type | Test Command |
|------|------|--------------|
| `package.json` | Node.js | `npm test` |
| `pyproject.toml` | Python (modern) | `pytest` |
| `setup.py` | Python (legacy) | `python -m pytest` |
| `requirements.txt` | Python | `pytest` |
| `go.mod` | Go | `go test ./...` |
| `Cargo.toml` | Rust | `cargo test` |
| `Makefile` | Make-based | `make test` |
| `pom.xml` | Java/Maven | `mvn test` |
| `build.gradle` | Java/Gradle | `gradle test` |

### 2. Find Test Files

```bash
# Python
find . -name "test_*.py" -o -name "*_test.py" | head -20

# JavaScript/TypeScript
find . -name "*.test.js" -o -name "*.spec.ts" | head -20

# Go
find . -name "*_test.go" | head -20

# Rust
grep -r "#\[test\]" src/ tests/ 2>/dev/null | head -20
```

### 3. Identify Config Files

```bash
# Test configs
ls -la pytest.ini pyproject.toml jest.config.* vitest.config.* .mocharc.* 2>/dev/null

# CI configs
ls -la .github/workflows/*.yml .gitlab-ci.yml Jenkinsfile 2>/dev/null
```

### 4. Check Dependencies

```bash
# Python
pip list 2>/dev/null | grep -iE "pytest|unittest|nose"

# Node
npm ls 2>/dev/null | grep -iE "jest|mocha|vitest|playwright"
```

## Output

Report in this format:
```
Project Type: [type]
Test Framework: [framework]
Test Files Found: [count]
Test Command: [command]
Config Files: [list]
```
