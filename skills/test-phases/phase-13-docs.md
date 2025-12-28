# Phase 13: Documentation Review

Audit documentation quality and completeness.

## Files to Check

| File | Required | Purpose |
|------|----------|---------|
| `README.md` | ✅ | Project overview |
| `CHANGELOG.md` | Recommended | Version history |
| `CONTRIBUTING.md` | For OSS | Contribution guide |
| `LICENSE` | ✅ | Legal terms |
| `docs/` | Optional | Detailed docs |
| `API.md` | If API exists | API reference |

## Execution Steps

### 1. Check Required Files

```bash
for file in README.md LICENSE; do
  if [ -f "$file" ]; then
    echo "✅ $file exists ($(wc -l < $file) lines)"
  else
    echo "❌ $file MISSING"
  fi
done
```

### 2. README Quality Check

```bash
# Check for essential sections
for section in "Installation" "Usage" "License"; do
  if grep -qi "^#.*$section\|^##.*$section" README.md; then
    echo "✅ $section section found"
  else
    echo "⚠️ Missing $section section"
  fi
done

# Check for code examples
if grep -q '```' README.md; then
  echo "✅ Contains code examples"
else
  echo "⚠️ No code examples"
fi
```

### 3. Docstring Coverage (Python)

```bash
# Check for missing docstrings
if command -v pydocstyle &>/dev/null; then
  pydocstyle . --count 2>&1 | tail -5
fi

# Count functions without docstrings
grep -rn "def " --include="*.py" | wc -l  # Total functions
grep -rn '"""' --include="*.py" | wc -l   # Docstrings (rough)
```

### 4. JSDoc Coverage (JavaScript)

```bash
# Check for JSDoc comments
grep -rn "/\*\*" --include="*.js" --include="*.ts" | wc -l
```

### 5. API Documentation

```bash
# Check if API is documented
if [ -d "docs/api" ] || [ -f "API.md" ] || [ -f "openapi.yaml" ]; then
  echo "✅ API documentation exists"
else
  # Check if project has API endpoints
  if grep -rq "@app.route\|@router\|app.get\|app.post" --include="*.py" --include="*.ts"; then
    echo "⚠️ API exists but no documentation"
  fi
fi
```

### 6. Changelog Check

```bash
if [ -f "CHANGELOG.md" ]; then
  # Check format (Keep a Changelog)
  if grep -q "## \[Unreleased\]\|## \[[0-9]" CHANGELOG.md; then
    echo "✅ CHANGELOG follows standard format"
  fi

  # Check recent entry
  latest=$(grep -m1 "## \[" CHANGELOG.md)
  echo "Latest: $latest"
fi
```

## Output Format

```
DOCUMENTATION AUDIT
───────────────────

Required Files:
  ✅ README.md (145 lines)
  ✅ LICENSE (MIT)
  ⚠️ CHANGELOG.md missing

README Quality:
  ✅ Installation section
  ✅ Usage section
  ✅ Code examples
  ⚠️ Missing API section
  ⚠️ Missing Contributing section

Code Documentation:
  Python docstrings: 67% coverage
  Missing docstrings: 12 functions

RECOMMENDATIONS:
1. Add CHANGELOG.md
2. Document 12 public functions
3. Add API reference section to README
```
