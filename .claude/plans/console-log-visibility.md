# Plan: Console Log Visibility for Claude Code

## Goal

Make browser console logs accessible to Claude Code via Chrome MCP tools, reducing dependency on screenshots for debugging.

## Current State

- Ruby code logs via `JSBridge.log` and `JSBridge.error` which call `console.log` and `console.error`
- JavaScript logs via `console.log('[JS] ...')`
- Chrome MCP tools can read console output, but logs are transient and may be missed
- Debug information is partially displayed on-screen (status area) but not complete

## Target Design

### Structured Log Buffer

Maintain a ring buffer of log entries in JavaScript, accessible via a global API:

```javascript
window.logBuffer = {
  entries: [],        // Ring buffer of {timestamp, level, source, message}
  maxSize: 500,       // Keep last 500 entries

  add(level, source, message) { ... },
  getAll() { return this.entries; },
  getLast(n) { return this.entries.slice(-n); },
  getByLevel(level) { return this.entries.filter(e => e.level === level); },
  getBySource(source) { return this.entries.filter(e => e.source === source); },
  clear() { this.entries = []; },
  dump() { /* formatted string output */ }
};
```

### Console Override

Intercept `console.log`, `console.error`, `console.warn` to capture all output:

```javascript
const originalLog = console.log.bind(console);
console.log = function(...args) {
  originalLog(...args);
  const msg = args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
  const source = msg.startsWith('[Ruby]') ? 'ruby' : msg.startsWith('[JS]') ? 'js' : 'other';
  window.logBuffer.add('log', source, msg);
};
```

### Chrome MCP Access Pattern

From Claude Code, use Chrome MCP tools to:
```javascript
// Get last 20 log entries
JSON.stringify(window.logBuffer.getLast(20))

// Get all errors
JSON.stringify(window.logBuffer.getByLevel('error'))

// Get Ruby-only logs
JSON.stringify(window.logBuffer.getBySource('ruby'))

// Dump formatted
window.logBuffer.dump()
```

### Ruby-Side Structured Logging

Enhance `JSBridge` to emit structured log data:

```ruby
module JSBridge
  def self.log(message, level: 'info', data: nil)
    # Human-readable console output
    JS.global[:console].log("[Ruby] #{message}")
    # Structured data for programmatic access
    if data
      JS.global.addStructuredLog(level, 'ruby', message, data)
    end
  end
end
```

## Changes Required

### 1. `index.html` (requires user approval)
- Add `logBuffer` object initialization (early in script loading)
- Add console override (before any other scripts)
- Add `addStructuredLog` global function for Ruby

### 2. `src/ruby/js_bridge.rb`
- Add optional structured data parameter to `log` and `error`

### 3. Documentation
- Add Chrome MCP log access patterns to `.claude/guides/` or `.claude/INVESTIGATION-PROTOCOL.md`

## TDD Approach

1. Write tests for logBuffer ring buffer behavior (add, getLast, getByLevel)
2. Implement logBuffer in index.html
3. Test console override captures logs correctly
4. Test Ruby structured logging via JSBridge
5. Verify with Chrome MCP tools (local session - required for final validation)

## Estimated Scope

- Files: `index.html` (requires user approval), `js_bridge.rb`, documentation
- Risk: Low (additive, no behavior changes to existing code)
- Note: Final verification requires local Chrome MCP session
