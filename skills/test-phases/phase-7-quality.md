# Phase 7: Code Quality

> **Model**: `opus` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for linters/formatters. Parallelize with other Tier 3 phases.

Comprehensive linting, formatting, dead code detection, complexity analysis, and style checks.

## Execution Steps

### 1. Python Analysis

```bash
echo "==================================================================="
echo "  PHASE 7: CODE QUALITY"
echo "==================================================================="

PYTHON_FILES=$(find . -name "*.py" -not -path "./.venv/*" -not -path "./venv/*" -not -path "./.snapshots/*" -not -path "./node_modules/*" 2>/dev/null | head -1)

if [[ -n "$PYTHON_FILES" ]]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "  Python Analysis"
    echo "-------------------------------------------------------------------"

    # Ruff - Fast, comprehensive linter (preferred)
    if command -v ruff &>/dev/null; then
        echo ""
        echo "Running Ruff (linting)..."
        ruff check . --output-format=grouped 2>&1 | head -50
        echo ""
        echo "Ruff Summary:"
        ruff check . --statistics 2>&1 | tail -10
    else
        echo "SKIP: ruff not installed"
    fi

    # Pylint - Deep analysis
    if command -v pylint &>/dev/null; then
        echo ""
        echo "Running Pylint (deep analysis)..."
        PY_LIST=$(find . -name "*.py" -not -path "./.venv/*" -not -path "./venv/*" -not -path "./.snapshots/*" -not -path "./node_modules/*" 2>/dev/null | head -20 | tr '\n' ' ')
        pylint --output-format=text --reports=n $PY_LIST 2>&1 | head -40
    else
        echo "SKIP: pylint not installed"
    fi

    # Mypy - Type checking
    if command -v mypy &>/dev/null; then
        echo ""
        echo "Running Mypy (type checking)..."
        mypy . --ignore-missing-imports --show-error-codes 2>&1 | head -30
    else
        echo "SKIP: mypy not installed"
    fi

    # Black - Format check
    if command -v black &>/dev/null; then
        echo ""
        echo "Checking Black formatting..."
        black --check --diff . 2>&1 | head -30
    else
        echo "SKIP: black not installed"
    fi

    # isort - Import sorting check
    if command -v isort &>/dev/null; then
        echo ""
        echo "Checking import sorting (isort)..."
        isort --check-only --diff . 2>&1 | head -20
    else
        echo "SKIP: isort not installed"
    fi

    # Radon - Complexity analysis
    if command -v radon &>/dev/null; then
        echo ""
        echo "Running Radon (complexity analysis)..."
        echo "Cyclomatic Complexity (grade C or worse):"
        radon cc . -a -s -n C --exclude ".venv/*,venv/*,.snapshots/*" 2>&1 | head -20
        echo ""
        echo "Maintainability Index:"
        radon mi . --exclude ".venv/*,venv/*,.snapshots/*" 2>&1 | head -10
    else
        echo "SKIP: radon not installed"
    fi

    # pydocstyle - Docstring checking
    if command -v pydocstyle &>/dev/null; then
        echo ""
        echo "Checking docstrings (pydocstyle)..."
        pydocstyle . --count 2>&1 | tail -5
    else
        echo "SKIP: pydocstyle not installed"
    fi
fi
```

### 2. Dead Code Detection

```bash
PYTHON_FILES=$(find . -name "*.py" -not -path "./.venv/*" -not -path "./venv/*" -not -path "./.snapshots/*" -not -path "./node_modules/*" 2>/dev/null | head -1)
JS_FILES=$(find . -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" 2>/dev/null | grep -v node_modules | grep -v .snapshots | head -1)
GO_FILES=$(find . -name "*.go" -not -path "./.snapshots/*" 2>/dev/null | head -1)

if [[ -n "$PYTHON_FILES" ]] || [[ -n "$JS_FILES" ]] || [[ -n "$GO_FILES" ]]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "  Dead Code Detection"
    echo "-------------------------------------------------------------------"
fi

if [[ -n "$PYTHON_FILES" ]]; then
    # Vulture - dead code finder (Python)
    if command -v vulture &>/dev/null; then
        echo ""
        echo "Running Vulture (dead code, min-confidence 80%)..."
        vulture . --min-confidence 80 --exclude ".venv,venv,.snapshots" 2>&1 | head -30
        VULTURE_COUNT=$(vulture . --min-confidence 80 --exclude ".venv,venv,.snapshots" 2>&1 | wc -l)
        echo "Dead code candidates: $VULTURE_COUNT"
    else
        echo "SKIP: vulture not installed"
    fi

    # Autoflake - unused imports/variables (Python)
    if command -v autoflake &>/dev/null; then
        echo ""
        echo "Running Autoflake (unused imports check)..."
        autoflake --check --remove-all-unused-imports --remove-unused-variables -r . --exclude .venv,venv,.snapshots 2>&1 | head -30
    else
        echo "SKIP: autoflake not installed"
    fi
fi

if [[ -n "$GO_FILES" ]]; then
    # deadcode - dead code finder (Go)
    if command -v deadcode &>/dev/null; then
        echo ""
        echo "Running deadcode (Go)..."
        deadcode ./... 2>&1 | head -20
    else
        echo "SKIP: deadcode not installed (install: go install golang.org/x/tools/cmd/deadcode@latest)"
    fi
fi

# Deprecated/TODO markers across all languages
echo ""
echo "Scanning for deprecation and removal markers..."
MARKERS=$(grep -rn "# TODO.*delete\|# TODO.*remove\|# DEPRECATED\|# REMOVE\|// TODO.*delete\|// DEPRECATED\|@deprecated" \
    --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.rs" \
    --exclude-dir=.venv --exclude-dir=venv --exclude-dir=node_modules --exclude-dir=.snapshots \
    . 2>/dev/null | head -20)
if [[ -n "$MARKERS" ]]; then
    echo "$MARKERS"
    MARKER_COUNT=$(echo "$MARKERS" | wc -l)
    echo "Deprecation/removal markers found: $MARKER_COUNT"
else
    echo "No deprecation/removal markers found."
fi

# Large files (candidates for splitting)
echo ""
echo "Large files (>500 lines):"
LARGE_FILES=$(find . -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" 2>/dev/null | \
    grep -v node_modules | grep -v .venv | grep -v venv | grep -v .snapshots | \
    xargs wc -l 2>/dev/null | awk '$1 > 500 && !/total$/ {print}' | sort -rn | head -10)
if [[ -n "$LARGE_FILES" ]]; then
    echo "$LARGE_FILES"
else
    echo "None found."
fi
```

### 3. Shell Script Analysis

```bash
# Find shell scripts by extension, then filter by shebang.
# Scripts without a shebang or with non-bash/sh shebangs are skipped by shfmt.
ALL_SCRIPTS=$(find . -name "*.sh" -not -path "./.snapshots/*" -not -path "./.venv/*" -not -path "./node_modules/*" 2>/dev/null)

BASH_SCRIPTS=""
ZSH_SCRIPTS=""
NO_SHEBANG_SCRIPTS=""

if [[ -n "$ALL_SCRIPTS" ]]; then
    while IFS= read -r f; do
        FIRST_LINE=$(head -1 "$f" 2>/dev/null)
        if echo "$FIRST_LINE" | grep -qE '#!/.*(bash|sh)'; then
            BASH_SCRIPTS="${BASH_SCRIPTS}${f}"$'\n'
        elif echo "$FIRST_LINE" | grep -qE '#!/.*zsh'; then
            ZSH_SCRIPTS="${ZSH_SCRIPTS}${f}"$'\n'
        else
            NO_SHEBANG_SCRIPTS="${NO_SHEBANG_SCRIPTS}${f}"$'\n'
        fi
    done <<< "$ALL_SCRIPTS"
fi

if [[ -n "$BASH_SCRIPTS" ]] || [[ -n "$ZSH_SCRIPTS" ]] || [[ -n "$NO_SHEBANG_SCRIPTS" ]]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "  Shell Script Analysis"
    echo "-------------------------------------------------------------------"

    # ShellCheck (works on bash/sh scripts)
    if command -v shellcheck &>/dev/null && [[ -n "$BASH_SCRIPTS" ]]; then
        echo ""
        echo "Running ShellCheck..."
        echo "$BASH_SCRIPTS" | tr -s '\n' | xargs shellcheck -f gcc 2>&1 | head -30
        SC_COUNT=$(echo "$BASH_SCRIPTS" | tr -s '\n' | xargs shellcheck -f gcc 2>&1 | grep -c ":" || echo "0")
        echo "ShellCheck issues: $SC_COUNT"
    elif ! command -v shellcheck &>/dev/null; then
        echo "SKIP: shellcheck not installed"
    fi

    # shfmt - Format check (bash/sh scripts ONLY)
    if command -v shfmt &>/dev/null && [[ -n "$BASH_SCRIPTS" ]]; then
        echo ""
        echo "Checking shell formatting (shfmt, bash/sh only)..."
        SHFMT_ISSUES=$(echo "$BASH_SCRIPTS" | tr -s '\n' | xargs shfmt -d 2>&1 | grep -c "^---" || echo "0")
        echo "Files needing formatting: $SHFMT_ISSUES"
    elif ! command -v shfmt &>/dev/null; then
        echo "SKIP: shfmt not installed"
    fi

    if [[ -n "$ZSH_SCRIPTS" ]]; then
        ZSH_COUNT=$(echo "$ZSH_SCRIPTS" | tr -s '\n' | grep -c . || echo "0")
        echo ""
        echo "Skipped $ZSH_COUNT zsh script(s) (shfmt/shellcheck do not support zsh)"
    fi

    if [[ -n "$NO_SHEBANG_SCRIPTS" ]]; then
        NS_COUNT=$(echo "$NO_SHEBANG_SCRIPTS" | tr -s '\n' | grep -c . || echo "0")
        echo ""
        echo "Skipped $NS_COUNT script(s) without recognized shebang"
    fi
fi
```

### 4. JavaScript/TypeScript Analysis

```bash
if [[ -f package.json ]]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "  JavaScript/TypeScript Analysis"
    echo "-------------------------------------------------------------------"

    # ESLint (includes no-unused-vars for dead code)
    if command -v eslint &>/dev/null || [[ -f node_modules/.bin/eslint ]]; then
        echo ""
        echo "Running ESLint..."
        npx eslint . --ext .js,.ts,.tsx,.jsx --format stylish 2>&1 | head -50
        echo ""
        echo "Checking for unused variables/dead code..."
        npx eslint . --ext .js,.ts,.tsx,.jsx --rule 'no-unused-vars: warn' --rule 'no-unreachable: warn' --format compact 2>&1 | grep -E "no-unused-vars|no-unreachable" | head -20
    else
        echo "SKIP: eslint not installed"
    fi

    # TypeScript compiler check
    if [[ -f tsconfig.json ]]; then
        if command -v tsc &>/dev/null || [[ -f node_modules/.bin/tsc ]]; then
            echo ""
            echo "Running TypeScript type check..."
            npx tsc --noEmit 2>&1 | head -30
        else
            echo "SKIP: tsc not installed"
        fi
    fi

    # Prettier - Format check
    if command -v prettier &>/dev/null || [[ -f node_modules/.bin/prettier ]]; then
        echo ""
        echo "Checking Prettier formatting..."
        npx prettier --check "**/*.{js,ts,tsx,jsx,json,css,scss}" 2>&1 | head -20
    else
        echo "SKIP: prettier not installed"
    fi
fi
```

### 5. Go Analysis

```bash
if [[ -f go.mod ]]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "  Go Analysis"
    echo "-------------------------------------------------------------------"

    # golangci-lint (comprehensive)
    if command -v golangci-lint &>/dev/null; then
        echo ""
        echo "Running golangci-lint..."
        golangci-lint run 2>&1 | head -50
    elif command -v go &>/dev/null; then
        echo ""
        echo "Running go vet (golangci-lint not installed)..."
        go vet ./... 2>&1
    else
        echo "SKIP: neither golangci-lint nor go installed"
    fi

    # Format check
    if command -v gofmt &>/dev/null; then
        echo ""
        echo "Checking Go formatting..."
        GOFMT_ISSUES=$(gofmt -l . 2>&1 | wc -l)
        echo "Files needing gofmt: $GOFMT_ISSUES"
    fi
fi
```

### 6. Rust Analysis

```bash
CARGO_DIR=""
if [[ -f Cargo.toml ]]; then
    CARGO_DIR="."
elif FOUND=$(find . -maxdepth 2 -name "Cargo.toml" -not -path "./.snapshots/*" -printf '%h\n' -quit 2>/dev/null) && [[ -n "$FOUND" ]]; then
    CARGO_DIR="$FOUND"
fi

if [[ -n "$CARGO_DIR" ]]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "  Rust Analysis (in $CARGO_DIR)"
    echo "-------------------------------------------------------------------"

    pushd "$CARGO_DIR" > /dev/null

    if command -v cargo &>/dev/null; then
        echo ""
        echo "Running cargo clippy..."
        cargo clippy -- -D warnings 2>&1 | head -50

        echo ""
        echo "Checking Rust formatting..."
        cargo fmt -- --check 2>&1 | head -20

        if command -v cargo-deny &>/dev/null; then
            echo ""
            echo "Running cargo deny check..."
            cargo deny check 2>&1 | tail -30
        else
            echo "SKIP: cargo-deny not installed"
        fi
    else
        echo "SKIP: cargo not installed"
    fi

    popd > /dev/null
fi
```

### 7. YAML/Config & Docker Analysis

```bash
YAML_FILES=$(find . -name "*.yml" -o -name "*.yaml" 2>/dev/null | grep -v node_modules | grep -v .snapshots | head -1)

if [[ -n "$YAML_FILES" ]]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "  YAML/Config Analysis"
    echo "-------------------------------------------------------------------"

    if command -v yamllint &>/dev/null; then
        echo "Running yamllint..."
        yamllint . 2>&1 | head -30
    else
        echo "SKIP: yamllint not installed"
    fi
fi

DOCKERFILES=$(find . -name "Dockerfile" -o -name "Dockerfile.*" 2>/dev/null | grep -v .snapshots | head -1)

if [[ -n "$DOCKERFILES" ]]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "  Docker Analysis"
    echo "-------------------------------------------------------------------"

    if command -v hadolint &>/dev/null; then
        echo "Running Hadolint..."
        find . -name "Dockerfile" -o -name "Dockerfile.*" 2>/dev/null | grep -v .snapshots | xargs hadolint 2>&1
    else
        echo "SKIP: hadolint not installed"
    fi

    if [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
        if command -v docker &>/dev/null; then
            echo ""
            echo "Validating docker-compose..."
            docker compose config --quiet 2>&1 && echo "PASS: docker-compose config is valid" || echo "FAIL: docker-compose config has errors"
        fi
    fi
fi
```

### 8. Documentation & Spelling

```bash
MD_FILES=$(find . -name "*.md" -not -path "./node_modules/*" -not -path "./.snapshots/*" -not -path "./.venv/*" 2>/dev/null | head -1)

if [[ -n "$MD_FILES" ]]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "  Documentation Quality"
    echo "-------------------------------------------------------------------"

    if command -v markdownlint &>/dev/null; then
        echo "Running markdownlint..."
        markdownlint '**/*.md' --ignore node_modules --ignore .snapshots --ignore .venv 2>&1 | head -30
    else
        echo "SKIP: markdownlint not installed"
    fi
fi

echo ""
echo "-------------------------------------------------------------------"
echo "  Spelling Check"
echo "-------------------------------------------------------------------"

if command -v codespell &>/dev/null; then
    echo "Running codespell..."
    codespell --skip=".git,.venv,venv,node_modules,.snapshots,*.lock,package-lock.json" . 2>&1 | head -30
    SPELLING_ISSUES=$(codespell --skip=".git,.venv,venv,node_modules,.snapshots,*.lock,package-lock.json" . 2>&1 | wc -l)
    echo "Spelling issues found: $SPELLING_ISSUES"
else
    echo "SKIP: codespell not installed"
fi
```

## Pass/Fail Criteria

| Category | PASS | FAIL |
|----------|------|------|
| Linting (ruff/pylint/eslint/clippy) | 0 errors (warnings OK) | Any errors |
| Type checking (mypy/tsc) | 0 type errors | Any type errors |
| Formatting (black/prettier/gofmt/shfmt/rustfmt) | 0 files need formatting | Any files need formatting |
| Dead code (vulture/autoflake/deadcode) | 0 high-confidence findings | Any findings at 80%+ confidence |
| Complexity (radon) | No function grade D or worse | Any function grade D+ (CC > 20) |
| Docker (hadolint) | 0 errors (DL info OK) | Any DL errors |
| Spelling (codespell) | 0 issues | Any issues |

**Overall**: PASS requires all categories to pass. Any single FAIL means the phase reports ISSUES FOUND.

## Integration with Phase 10

Issues are collected for Phase 10 (Fix) to process. The collection avoids assuming jq is installed.

```bash
QUALITY_ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/quality-issues.txt"

collect_quality_issues() {
    > "$QUALITY_ISSUES_FILE"

    # Ruff issues (auto-fixable)
    if command -v ruff &>/dev/null; then
        echo "## Ruff Issues" >> "$QUALITY_ISSUES_FILE"
        ruff check . --output-format=text 2>/dev/null | head -50 >> "$QUALITY_ISSUES_FILE"
        echo "" >> "$QUALITY_ISSUES_FILE"
    fi

    # Black formatting
    if command -v black &>/dev/null; then
        echo "## Black Formatting" >> "$QUALITY_ISSUES_FILE"
        black --check . 2>&1 | grep "would reformat" >> "$QUALITY_ISSUES_FILE"
        echo "" >> "$QUALITY_ISSUES_FILE"
    fi

    # Dead code (vulture)
    if command -v vulture &>/dev/null; then
        echo "## Dead Code (Vulture)" >> "$QUALITY_ISSUES_FILE"
        vulture . --min-confidence 80 --exclude ".venv,venv,.snapshots" 2>&1 | head -30 >> "$QUALITY_ISSUES_FILE"
        echo "" >> "$QUALITY_ISSUES_FILE"
    fi

    # Unused imports (autoflake)
    if command -v autoflake &>/dev/null; then
        echo "## Unused Imports (Autoflake)" >> "$QUALITY_ISSUES_FILE"
        autoflake --check --remove-all-unused-imports -r . --exclude .venv,venv,.snapshots 2>&1 | head -30 >> "$QUALITY_ISSUES_FILE"
        echo "" >> "$QUALITY_ISSUES_FILE"
    fi

    # Spelling
    if command -v codespell &>/dev/null; then
        echo "## Spelling Issues" >> "$QUALITY_ISSUES_FILE"
        codespell --skip=".git,.venv,venv,node_modules,.snapshots,*.lock,package-lock.json" . 2>&1 | head -30 >> "$QUALITY_ISSUES_FILE"
        echo "" >> "$QUALITY_ISSUES_FILE"
    fi

    LINE_COUNT=$(wc -l < "$QUALITY_ISSUES_FILE")
    if [[ "$LINE_COUNT" -gt 5 ]]; then
        echo "Quality issues collected to: $QUALITY_ISSUES_FILE"
    else
        echo "No quality issues to collect."
        rm -f "$QUALITY_ISSUES_FILE"
    fi
}

collect_quality_issues
```
