# Phase H: Holistic Full-Stack Analysis

A comprehensive analysis that views the entire codebase as an interconnected system - understanding how shell scripts, Python backend, web frontend, and services relate to and depend on each other.

## Philosophy

**Every piece of code exists in relationship to others.** A bug in a shell script may manifest as a UI issue. A Python API change requires corresponding JavaScript updates. CSS styling decisions affect user perception of functionality. This phase treats the codebase as a living organism, not isolated files.

## When to Use

- After major refactoring affecting multiple components
- When symptoms appear disconnected from their root cause (like the parallelism bug causing UI to show wrong numbers)
- Before releases to ensure cross-component consistency
- When inheriting or auditing an unfamiliar codebase

## Analysis Domains

### 1. Shell Scripts (`scripts/`, `*.sh`)

```yaml
analyze:
  - Variable expansion correctness (`: > "$var"` not `: > "var"`)
  - Consistent error handling patterns across all scripts
  - Shared configuration sourcing (`source lib/audiobooks-config.sh`)
  - Exit code propagation and signal handling
  - Logging consistency (format, destinations, verbosity levels)
  - Inter-script dependencies (which scripts call which)
  - Shellcheck compliance with project-specific exclusions

cross_reference:
  - Do shell scripts match Python expectations for file paths, formats?
  - Are environment variables consistent between shell and Python?
  - Do script outputs match what the API expects to parse?
```

### 2. Python Backend (`library/backend/`, `*.py`)

```yaml
analyze:
  - Database connection handling (connection leaks, proper closing)
  - API endpoint consistency (naming, response formats, error handling)
  - Import organization and circular dependency risks
  - Type hints completeness and accuracy
  - Exception handling patterns (catch-all vs specific)
  - Configuration loading (env vars, config files, defaults)
  - Process spawning and subprocess management

cross_reference:
  - Do API responses match what JavaScript expects?
  - Are database paths consistent with shell script expectations?
  - Do Python-spawned processes use correct shell script paths?
  - Are status codes used consistently across all endpoints?
```

### 3. Web Frontend (`library/web-v2/`, HTML/CSS/JS)

```yaml
analyze:
  - API endpoint URLs match actual backend routes
  - Error handling for failed API calls
  - Loading states and user feedback
  - CSS class naming consistency
  - JavaScript event handling and memory leaks
  - Accessibility (ARIA, keyboard navigation, screen readers)
  - Responsive design breakpoints
  - Theme/color consistency

cross_reference:
  - Do fetch() URLs match Flask route definitions?
  - Are API response fields correctly parsed in JavaScript?
  - Do UI states reflect actual backend states accurately?
  - Are error messages user-friendly translations of backend errors?
```

### 4. Service Integration (`systemd/`, service files)

```yaml
analyze:
  - Service dependencies (After=, Requires=, Wants=)
  - User/group permissions across services
  - Working directory consistency
  - Environment file loading
  - Restart policies and failure handling
  - Resource limits (memory, CPU, file descriptors)
  - Log destinations and rotation

cross_reference:
  - Do service paths match installed file locations?
  - Are service users consistent with file ownership?
  - Do services start in correct order for dependencies?
  - Are socket/port configurations consistent across services?
```

### 5. Data Flow Mapping

```yaml
trace_flows:
  - Source file → Queue → Converter → Staging → Library → Database → UI
  - User action → JavaScript → API → Python → Database → Response → UI update
  - Configuration → Shell scripts → Python → Templates → Rendered output
  - Error occurrence → Logging → Log files → UI display

identify:
  - Where data transformations occur
  - Where data can be lost or corrupted
  - Where race conditions can occur
  - Where caching might serve stale data
```

## Execution Steps

### Step 1: Dependency Mapping

Build a dependency graph showing which files depend on which:

```bash
# Find all imports, sources, and references
grep -r "from .* import\|import .*\|source .*\|require(" --include="*.py" --include="*.sh" --include="*.js"
```

Create a mental model of:
- Which shell scripts call other shell scripts
- Which Python modules import which
- Which JavaScript files load which
- Which config files are read by which components

### Step 2: Configuration Audit

Ensure configuration consistency:

```yaml
check:
  - All path variables point to same locations across languages
  - Port numbers consistent (shell, Python, systemd, nginx)
  - Database path same in all references
  - API base URLs consistent in JavaScript
  - Environment variable names match between .env, systemd, shell
```

### Step 3: Interface Contract Verification

For each API endpoint:
1. Document the expected request format
2. Document the response format
3. Verify JavaScript code sends/parses correctly
4. Verify error responses are handled

For each shell script output:
1. Document the expected output format
2. Verify any parsers (Python/JavaScript) handle it correctly
3. Verify error cases produce parseable output

### Step 4: State Consistency Audit

Check that state is consistent across views:

```yaml
verify:
  - File counts in shell match database counts
  - Queue file entries match API queue endpoint response
  - Service status in systemd matches API service status endpoint
  - Conversion progress calculation consistent between components
```

### Step 5: Error Propagation Tracing

For each error type:
1. Where can it originate?
2. How does it propagate through the stack?
3. What does the user ultimately see?
4. Is the error message actionable?

### Step 6: Design Philosophy Enforcement

```yaml
principles:
  - DRY: Is configuration duplicated? Should it be centralized?
  - Single Source of Truth: Which component is authoritative for each data type?
  - Fail Fast: Do errors surface immediately or silently corrupt state?
  - Graceful Degradation: If one component fails, do others handle it?
  - Consistency: Do similar operations work similarly across the codebase?
```

## Common Cross-Component Issues

### Issue: Hardcoded Paths

**Symptom**: Works in development, breaks in production
**Check**: Search for absolute paths that should be configurable
```bash
grep -rn "/opt/audiobooks\|/raid0/Audiobooks\|/var/lib/audiobooks" --include="*.py" --include="*.sh" --include="*.js"
```
**Fix**: Use configuration variables consistently

### Issue: Inconsistent Error Handling

**Symptom**: Some errors show user-friendly messages, others show stack traces
**Check**: Audit all try/except blocks and error responses
**Fix**: Implement consistent error wrapper/handler

### Issue: Race Conditions

**Symptom**: Intermittent failures, data inconsistency
**Check**: Look for shared resources accessed without locking
**Fix**: Add appropriate locking (flock for shell, threading locks for Python)

### Issue: Stale UI State

**Symptom**: UI shows incorrect data until manual refresh
**Check**: Verify all state-changing operations trigger UI updates
**Fix**: Implement proper event-driven updates or polling

### Issue: Silent Failures

**Symptom**: Operations fail but no error shown
**Check**: Trace all error paths to ensure they surface to user
**Fix**: Add proper error propagation and user notification

## Output Format

### Dependency Map
```
┌─────────────────────────────────────────────────────────────┐
│                    COMPONENT RELATIONSHIPS                   │
├─────────────────────────────────────────────────────────────┤
│ Shell Scripts                                                │
│   build-conversion-queue                                     │
│     ├── sources: lib/audiobooks-config.sh                   │
│     ├── writes: .index/queue.txt, .index/*.idx              │
│     └── called by: convert-audiobooks-opus-parallel         │
│                                                              │
│ Python Backend                                               │
│   utilities_conversion.py                                    │
│     ├── imports: subprocess, pathlib                        │
│     ├── reads: /proc/PID/io, .index/queue.txt               │
│     └── provides: /api/conversion/status endpoint           │
│                                                              │
│ JavaScript Frontend                                          │
│   utilities.js                                               │
│     ├── fetches: /api/conversion/status                     │
│     ├── updates: #conversion-progress, #active-jobs         │
│     └── polls: every 5s when visible                        │
└─────────────────────────────────────────────────────────────┘
```

### Issue Report
```
┌─────────────────────────────────────────────────────────────┐
│ CROSS-COMPONENT ISSUE #1                                     │
├─────────────────────────────────────────────────────────────┤
│ Title: Variable expansion bug breaks queue building          │
│ Severity: CRITICAL                                           │
│                                                              │
│ Affected Components:                                         │
│   • scripts/build-conversion-queue (root cause)             │
│   • library/backend/utilities_conversion.py (symptom)        │
│   • library/web-v2/js/utilities.js (visible effect)          │
│                                                              │
│ Root Cause:                                                  │
│   Shell script uses `: > "var"` instead of `: > "$var"`     │
│   causing queue file to never be properly cleared            │
│                                                              │
│ Cascade Effect:                                              │
│   Shell: Queue not built → Python: reads stale queue →       │
│   API: returns wrong count → JavaScript: displays wrong UI   │
│                                                              │
│ Fix: Correct variable expansion in 7 locations               │
└─────────────────────────────────────────────────────────────┘
```

## Autonomous Fix Protocol

When fixing cross-component issues:

1. **Fix the root cause first** - Don't patch symptoms
2. **Update all affected components** - If an API changes, update JS too
3. **Test the full flow** - Not just the changed file
4. **Document the relationship** - Add comments explaining cross-component dependencies
5. **Consider future maintenance** - Would this be caught by tests? Should we add one?

## Integration with Other Phases

- **Phase 1 (Discovery)**: Builds initial file inventory that Phase H uses
- **Phase 5 (Security)**: Security issues often span components (Phase H identifies the full attack surface)
- **Phase 7 (Quality)**: Code quality is Phase H's sister - H adds cross-component dimension
- **Phase 10 (Fix)**: Receives the fix list from Phase H for implementation
- **Phase P (Production)**: Validates that holistic fixes work in production environment

## Checklist

```
[ ] Dependency map created for all components
[ ] Configuration consistency verified across languages
[ ] API contracts verified (request/response formats)
[ ] Data flow traced from source to UI
[ ] Error propagation paths documented
[ ] Race condition risks identified
[ ] State consistency verified
[ ] Design principles checked
[ ] Cross-component issues fixed at root cause
[ ] All affected components updated together
[ ] Documentation reflects current interconnections
```
