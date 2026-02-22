---
name: verify
description: Full TDD + Chrome browser confirmation loop. Run after implementation to confirm tests pass and browser renders correctly.
disable-model-invocation: false
---

# Verify Workflow

Run this after implementing any change. Do NOT report completion until all steps pass.

## Step 1: Run Tests

```bash
bundle exec rake test
```

- If failures: fix them before proceeding. Do NOT skip to browser.
- Note the pass count for reference.

## Step 2: Hard Refresh Browser

Get the current tab:

```
mcp__claude-in-chrome__tabs_context_mcp(createIfEmpty: true)
```

Navigate with cache-busting URL:

```
mcp__claude-in-chrome__navigate(
  url: "http://localhost:8000/index.html?nocache=<random-number>",
  tabId: XXX
)
```

**CRITICAL**: Always use `?nocache=<random>`. ruby.wasm caches aggressively — without this, you may be testing stale code.

## Step 3: Wait for User Action

Display this message and PAUSE:

```
Browser loaded. Please:
- Upload VRM file if needed, OR click "Skip"
- Let me know when the visualizer is running
```

Do NOT proceed until user confirms ready.

## Step 4: Screenshot

```
mcp__claude-in-chrome__computer(
  action: "screenshot",
  tabId: XXX
)
```

Confirm visually:
- Particles visible
- No black screen or error overlay
- Expected visual change is present

## Step 5: Console Error Check

```
mcp__claude-in-chrome__read_console_messages(
  tabId: XXX,
  pattern: "Error|TypeError|Ruby|undefined",
  onlyErrors: true
)
```

If errors found: diagnose and fix before claiming done.

## Step 6: Report

Only after all steps pass, report:

```
Verify complete:
- Tests: NNN passing
- Browser: [screenshot description]
- Console: No errors
```

## Rules

- NEVER claim "it works" without completing steps 1-5
- If tests fail at step 1, fix and restart from step 1
- If console has errors at step 5, fix and restart from step 2
- Maximum 3 fix-and-retry loops before escalating to user
