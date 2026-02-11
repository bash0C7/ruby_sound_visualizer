---
name: browser-clean-session
description: Open visualizer in clean browser session with full cache clear
disable-model-invocation: false
---

# Browser Clean Session Launcher

Opens Ruby WASM Sound Visualizer in a fresh browser tab with complete cache clearing. This ensures all Ruby files and index.html are reloaded from server, not browser cache.

## When to Use

- After modifying index.html or Ruby source files
- When testing changes to audio processing logic
- When verifying VRM model loading behavior
- When previous session may have cached stale code

## Key Differences from debug-browser

- **debug-browser**: Connects to existing tab, waits for user action
- **browser-clean-session**: Creates NEW tab, clears cache, waits for USER action (not auto-wait)

## Workflow

### 1. Get Tab Context

```
mcp__claude-in-chrome__tabs_context_mcp(createIfEmpty: true)
```

- Creates MCP tab group if needed
- Returns available tab IDs

### 2. Create New Tab

```
mcp__claude-in-chrome__tabs_create_mcp()
```

- Fresh tab in the MCP group
- Isolated from previous sessions

### 3. Navigate with Cache-Busting URL

```
mcp__claude-in-chrome__navigate(
  url: "http://localhost:8000/index.html?nocache=<timestamp>",
  tabId: XXX
)
```

- `<timestamp>`: Use `Date.now()` or Unix timestamp for unique URL
- Prevents browser from serving cached HTML

### 4. Perform Hard Reload (CRITICAL)

Hard reload clears ALL caches including loaded scripts:

**Mac:**
```
mcp__claude-in-chrome__computer(
  action: "key",
  text: "cmd+shift+r",
  tabId: XXX
)
```

**Windows/Linux:**
```
mcp__claude-in-chrome__computer(
  action: "key",
  text: "ctrl+shift+r",
  tabId: XXX
)
```

Wait briefly for reload to complete:
```
mcp__claude-in-chrome__computer(
  action: "wait",
  duration: 2,
  tabId: XXX
)
```

### 5. Wait for User Instruction (DO NOT AUTO-WAIT)

Display message to user:

```
Browser session ready! The visualizer is loading Ruby WASM.

Next steps:
- If you need VRM model: Upload .vrm file when ready
- If you don't need VRM: Click "Skip" button
- Or provide your next instruction

Let me know when you're ready to proceed!
```

**IMPORTANT**: Pause skill execution here. Wait for user's response in chat.

### 6. After User Indicates Ready

Once user uploads VRM or clicks skip button:

**Take Screenshot:**
```
mcp__claude-in-chrome__computer(
  action: "screenshot",
  tabId: XXX
)
```

**Check Console Errors:**
```
mcp__claude-in-chrome__read_console_messages(
  tabId: XXX,
  pattern: "Error|TypeError|Ruby|undefined",
  onlyErrors: true,
  clear: false
)
```

**Report Status:**
- Confirm visual rendering (particles, torus, VRM if uploaded)
- List any console errors found
- Suggest next steps if issues detected

## Cache Clearing Methods

### Method 1: Hard Reload (Preferred)

Keyboard shortcut (`Cmd+Shift+R` / `Ctrl+Shift+R`) is most reliable:
- Clears HTTP cache
- Reloads all `<script>` tags (including `type="text/ruby"`)
- Bypasses service workers
- Forces fresh fetch from server

### Method 2: JavaScript Reload (Fallback)

If keyboard shortcut fails:
```javascript
mcp__claude-in-chrome__javascript_tool(
  tabId: XXX,
  text: "location.reload(true)"
)
```

**Note**: `location.reload(true)` is deprecated but still works in most browsers.

## Common Issues

### Server Not Running

**Symptom**: Navigation fails with "connection refused"

**Solution**:
```bash
rake server:status  # Check if running
rake server:start   # Start if needed
```

### Cache Still Served

**Symptom**: Changes not reflected after reload

**Solution**:
- Verify hard reload keyboard shortcut executed
- Check Network tab in DevTools (should show "Disable cache" enabled)
- Try closing tab and reopening with this skill

### Ruby WASM Not Initializing

**Symptom**: Console shows "Ruby script not loaded" or similar

**Solution**:
- Verify server is serving `.rb` files with correct MIME type
- Check browser console for CORS errors
- Use `/debug-browser` for detailed investigation

## Integration with Development Workflow

Typical usage pattern:

1. Edit code in index.html or src/ruby/*.rb
2. Run `/browser-clean-session`
3. Wait for user action (VRM upload or skip)
4. Verify changes visually + console
5. If issues found, use `/debug-browser` for detailed investigation

## Best Practices

1. **Always hard reload** - Don't skip step 4 (keyboard shortcut)
2. **Wait for user action** - Always wait for user to indicate ready
3. **Screenshot first** - Visual confirmation before reading logs
4. **Clear cache flag** - Use `?nocache=` parameter in URL
5. **One session per change** - Don't reuse tabs across edits
