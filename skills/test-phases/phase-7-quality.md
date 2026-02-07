# Phase 7: Code Quality

> **Model**: `opus` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for linters/formatters. Use `NotebookEdit` for Jupyter notebook quality checks. Use `WebSearch` to look up linter rule explanations for unfamiliar warnings. Parallelize with other Tier 3 phases.

Comprehensive linting, formatting, complexity analysis, and style checks using all available tools.

## MCP/LSP Server Integration

When LSP servers are available (detected in Phase 1), **prefer them over CLI tools** for richer, project-aware analysis:

| Language | LSP Server | Advantages over CLI |
|----------|------------|---------------------|
| Python | pyright-lsp | Full project context, cross-file type inference, faster |
| TypeScript/JS | typescript-lsp | Real-time diagnostics, project-wide analysis |
| Rust | rust-analyzer-lsp | Incremental analysis, macro expansion |
| Go | gopls-lsp | Project-aware analysis, cross-package refs |
| C/C++ | clangd-lsp | Compile-command aware, accurate diagnostics |

### Using LSP Servers

If LSP servers are enabled (from Discovery `MCP_AVAILABLE`):

```
# For Python projects with pyright-lsp enabled:
1. Invoke pyright-lsp diagnostics for the project
2. Collect type errors, undefined references, import issues
3. Still run ruff/black for formatting (LSP doesn't format)

# For TypeScript projects with typescript-lsp enabled:
1. Invoke typescript-lsp diagnostics
2. Collect type errors, unused variables, unreachable code
3. Still run prettier/eslint for formatting and style

# General pattern:
- LSP for type checking and semantic analysis
- CLI tools for formatting and style enforcement
```

**Note:** When both LSP and CLI tools are available, run both but deduplicate issues. LSP diagnostics are often more accurate for type-related issues.

## Execution Steps

### 1. Python Linting & Type Checking

```bash
echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE 7: CODE QUALITY"
echo "═══════════════════════════════════════════════════════════════════"

PYTHON_FILES=$(find . -name "*.py" -not -path "./.venv/*" -not -path "./venv/*" -not -path "./.snapshots/*" 2>/dev/null | head -1)

if [[ -n "$PYTHON_FILES" ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Python Analysis"
    echo "───────────────────────────────────────────────────────────────────"

    # Ruff - Fast, comprehensive linter (preferred)
    if command -v ruff &>/dev/null; then
        echo ""
        echo "Running Ruff (linting)..."
        ruff check . --output-format=grouped 2>&1 | head -50
        echo ""
        echo "Ruff Summary:"
        ruff check . --statistics 2>&1 | tail -10
    fi

    # Pylint - Deep analysis
    if command -v pylint &>/dev/null; then
        echo ""
        echo "Running Pylint (deep analysis)..."
        pylint --output-format=text --reports=n $(find . -name "*.py" -not -path "./.venv/*" -not -path "./venv/*" -not -path "./.snapshots/*" | head -20 | tr '\n' ' ') 2>&1 | head -40
    fi

    # Mypy - Type checking
    if command -v mypy &>/dev/null; then
        echo ""
        echo "Running Mypy (type checking)..."
        mypy . --ignore-missing-imports --show-error-codes 2>&1 | head -30
    fi

    # Black - Format check
    if command -v black &>/dev/null; then
        echo ""
        echo "Checking Black formatting..."
        black --check --diff . 2>&1 | head -30
    fi

    # isort - Import sorting check
    if command -v isort &>/dev/null; then
        echo ""
        echo "Checking import sorting (isort)..."
        isort --check-only --diff . 2>&1 | head -20
    fi

    # Radon - Complexity analysis
    if command -v radon &>/dev/null; then
        echo ""
        echo "Running Radon (complexity analysis)..."
        echo "Cyclomatic Complexity:"
        radon cc . -a -s --exclude ".venv/*,venv/*,.snapshots/*" 2>&1 | head -20
        echo ""
        echo "Maintainability Index:"
        radon mi . --exclude ".venv/*,venv/*,.snapshots/*" 2>&1 | head -10
    fi

    # pydocstyle - Docstring checking
    if command -v pydocstyle &>/dev/null; then
        echo ""
        echo "Checking docstrings (pydocstyle)..."
        pydocstyle . --count 2>&1 | tail -5
    fi
fi
```

### 2. Shell Script Analysis

```bash
SHELL_FILES=$(find . -name "*.sh" -not -path "./.snapshots/*" 2>/dev/null | head -1)

if [[ -n "$SHELL_FILES" ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Shell Script Analysis"
    echo "───────────────────────────────────────────────────────────────────"

    # ShellCheck - Linting
    if command -v shellcheck &>/dev/null; then
        echo ""
        echo "Running ShellCheck..."
        find . -name "*.sh" -not -path "./.snapshots/*" -exec shellcheck -f gcc {} \; 2>/dev/null | head -30
        echo ""
        SHELL_ISSUES=$(find . -name "*.sh" -not -path "./.snapshots/*" -exec shellcheck -f gcc {} \; 2>/dev/null | wc -l)
        echo "ShellCheck issues: $SHELL_ISSUES"
    fi

    # shfmt - Format check
    if command -v shfmt &>/dev/null; then
        echo ""
        echo "Checking shell formatting (shfmt)..."
        shfmt -d . 2>&1 | head -20
        SHFMT_ISSUES=$(shfmt -d . 2>&1 | grep -c "^---" || echo "0")
        echo "Files needing formatting: $SHFMT_ISSUES"
    fi
fi
```

### 3. JavaScript/TypeScript Analysis

```bash
if [[ -f package.json ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  JavaScript/TypeScript Analysis"
    echo "───────────────────────────────────────────────────────────────────"

    # ESLint
    if command -v eslint &>/dev/null || [[ -f node_modules/.bin/eslint ]]; then
        echo ""
        echo "Running ESLint..."
        npx eslint . --ext .js,.ts,.tsx,.jsx --format stylish 2>&1 | head -50
    fi

    # TypeScript compiler check
    if command -v tsc &>/dev/null || [[ -f node_modules/.bin/tsc ]]; then
        if [[ -f tsconfig.json ]]; then
            echo ""
            echo "Running TypeScript type check..."
            npx tsc --noEmit 2>&1 | head -30
        fi
    fi

    # Prettier - Format check
    if command -v prettier &>/dev/null || [[ -f node_modules/.bin/prettier ]]; then
        echo ""
        echo "Checking Prettier formatting..."
        npx prettier --check "**/*.{js,ts,tsx,jsx,json,css,scss,md}" 2>&1 | head -20
    fi

    # Complexity check via ESLint
    echo ""
    echo "Checking complexity..."
    npx eslint . --rule 'complexity: [warn, 10]' --format compact 2>&1 | grep complexity | head -10
fi
```

### 4. YAML/Config Analysis

```bash
YAML_FILES=$(find . -name "*.yml" -o -name "*.yaml" 2>/dev/null | grep -v node_modules | grep -v .snapshots | head -1)

if [[ -n "$YAML_FILES" ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  YAML/Config Analysis"
    echo "───────────────────────────────────────────────────────────────────"

    # yamllint
    if command -v yamllint &>/dev/null; then
        echo ""
        echo "Running yamllint..."
        yamllint . 2>&1 | head -30
    fi
fi
```

### 5. Docker Analysis

```bash
if [[ -f Dockerfile ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Docker Analysis"
    echo "───────────────────────────────────────────────────────────────────"

    # Hadolint
    if command -v hadolint &>/dev/null; then
        echo ""
        echo "Running Hadolint..."
        hadolint Dockerfile 2>&1
    fi

    # Check docker-compose if exists
    if [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
        if command -v docker-compose &>/dev/null; then
            echo ""
            echo "Validating docker-compose..."
            docker-compose config --quiet && echo "  ✅ docker-compose.yml is valid" || echo "  ❌ docker-compose.yml has errors"
        fi
    fi
fi
```

### 6. Documentation Quality

```bash
MD_FILES=$(find . -name "*.md" -not -path "./node_modules/*" -not -path "./.snapshots/*" 2>/dev/null | head -1)

if [[ -n "$MD_FILES" ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Documentation Quality"
    echo "───────────────────────────────────────────────────────────────────"

    # markdownlint
    if command -v markdownlint &>/dev/null; then
        echo ""
        echo "Running markdownlint..."
        markdownlint '**/*.md' --ignore node_modules --ignore .snapshots 2>&1 | head -30
    fi
fi
```

### 7. Spelling Check

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Spelling Check"
echo "───────────────────────────────────────────────────────────────────"

# codespell
if command -v codespell &>/dev/null; then
    echo ""
    echo "Running codespell..."
    codespell --skip=".git,.venv,venv,node_modules,.snapshots,*.lock,package-lock.json" . 2>&1 | head -30
    SPELLING_ISSUES=$(codespell --skip=".git,.venv,venv,node_modules,.snapshots,*.lock,package-lock.json" . 2>&1 | wc -l)
    echo "Spelling issues found: $SPELLING_ISSUES"
fi
```

### 8. Go Analysis

```bash
if [[ -f go.mod ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Go Analysis"
    echo "───────────────────────────────────────────────────────────────────"

    # golangci-lint (comprehensive)
    if command -v golangci-lint &>/dev/null; then
        echo ""
        echo "Running golangci-lint..."
        golangci-lint run 2>&1 | head -50
    else
        # Fallback to go vet
        echo ""
        echo "Running go vet..."
        go vet ./... 2>&1
    fi

    # Format check
    echo ""
    echo "Checking Go formatting..."
    GOFMT_ISSUES=$(gofmt -l . 2>&1 | wc -l)
    echo "Files needing gofmt: $GOFMT_ISSUES"
fi
```

### 9. Rust Analysis

```bash
if [[ -f Cargo.toml ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Rust Analysis"
    echo "───────────────────────────────────────────────────────────────────"

    # Clippy
    echo ""
    echo "Running cargo clippy..."
    cargo clippy -- -D warnings 2>&1 | head -50

    # Format check
    echo ""
    echo "Checking Rust formatting..."
    cargo fmt -- --check 2>&1 | head -20
fi
```

## Output Format

```
═══════════════════════════════════════════════════════════════════
  CODE QUALITY REPORT
═══════════════════════════════════════════════════════════════════

Language Analysis:
─────────────────────────────────────────────────────────────────
  Python:
    Ruff:         12 errors, 45 warnings
    Pylint:       Score 8.5/10
    Mypy:         5 type errors
    Black:        8 files need formatting
    isort:        3 files need import sorting
    Complexity:   2 functions above threshold (CC > 10)

  Shell:
    ShellCheck:   15 issues
    shfmt:        4 files need formatting

  JavaScript:
    ESLint:       23 issues
    TypeScript:   0 type errors
    Prettier:     12 files need formatting

  Config:
    yamllint:     3 issues
    Hadolint:     2 issues

  Documentation:
    markdownlint: 5 issues
    codespell:    8 typos

HIGH PRIORITY (Fix in Phase 10):
─────────────────────────────────────────────────────────────────
File                          Issue                           Tool
────────────────────────────────────────────────────────────────────
src/api/handlers.py:45        Cyclomatic complexity 15        radon
src/utils/parser.py:23        Type error: incompatible type   mypy
scripts/deploy.sh:12          SC2086: Quote to prevent glob   shellcheck
Dockerfile:15                 DL3008: Pin versions in apt-get hadolint

AUTO-FIXABLE:
─────────────────────────────────────────────────────────────────
  Formatting (black, prettier, gofmt, shfmt): 24 files
  Import sorting (isort, eslint): 3 files
  Spelling (codespell): 8 issues

Status: ⚠️ ISSUES FOUND - 87 total, 35 auto-fixable
```

## Integration with Phase 10

All issues identified in this phase should be collected for Phase 10 (Fix) to process:

```bash
# Create quality issues file for Phase 10
QUALITY_ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/quality-issues.json"

# Collect issues in JSON format for automated fixing
collect_quality_issues() {
    echo "[]" > "$QUALITY_ISSUES_FILE"

    # Ruff issues (auto-fixable)
    if command -v ruff &>/dev/null; then
        ruff check . --output-format=json 2>/dev/null | \
            jq '.[] | {tool: "ruff", file: .filename, line: .location.row, code: .code, message: .message, fixable: .fix != null}' >> "$QUALITY_ISSUES_FILE.tmp"
    fi

    # Black formatting
    if command -v black &>/dev/null; then
        black --check . 2>&1 | grep "would reformat" | \
            while read -r line; do
                file=$(echo "$line" | sed 's/would reformat //')
                echo "{\"tool\": \"black\", \"file\": \"$file\", \"fixable\": true}" >> "$QUALITY_ISSUES_FILE.tmp"
            done
    fi

    # ShellCheck issues
    if command -v shellcheck &>/dev/null; then
        find . -name "*.sh" -not -path "./.snapshots/*" -exec shellcheck -f json {} \; 2>/dev/null | \
            jq '.[] | {tool: "shellcheck", file: .file, line: .line, code: .code, message: .message, fixable: false}' >> "$QUALITY_ISSUES_FILE.tmp"
    fi

    # Combine all issues
    if [[ -f "$QUALITY_ISSUES_FILE.tmp" ]]; then
        jq -s '.' "$QUALITY_ISSUES_FILE.tmp" > "$QUALITY_ISSUES_FILE" 2>/dev/null
        rm -f "$QUALITY_ISSUES_FILE.tmp"
        echo "Quality issues collected to: $QUALITY_ISSUES_FILE"
    fi
}

collect_quality_issues
```
