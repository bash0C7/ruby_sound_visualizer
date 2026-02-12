---
name: debug-browser
description: Detailed browser debugging procedure for ruby.wasm app using Chrome MCP tools
disable-model-invocation: false
---

# Browser Debugging Workflow for Ruby WASM Sound Visualizer

## Step-by-Step Chrome MCP Tool Usage

### 1. Get Tab Context

```
mcp__claude-in-chrome__tabs_context_mcp(createIfEmpty: true)
```

- Returns available tab IDs in the current group
- Creates new MCP tab group if none exists

### 2. Create New Tab (if needed)

```
mcp__claude-in-chrome__tabs_create_mcp()
```

- Creates a fresh tab in the MCP group
- Returns the new tab ID

### 3. Navigate to Application

```
mcp__claude-in-chrome__navigate(
  url: "http://localhost:8000/index.html?nocache=<random>",
  tabId: XXX
)
```

- Use `?nocache=<random-number>` to bypass browser cache
- Wait for page load completion

### 4. Wait for User Action (CRITICAL)

Display message to user:

```
Browser session ready! The visualizer is loading Ruby WASM.

Next steps:
- If you need VRM model: Upload .vrm file when ready
- If you don't need VRM: Click "Skip" button
- Or provide your next instruction

Let me know when you're ready to proceed!
```

**IMPORTANT**:
- Pause skill execution here and wait for user's response in chat
- User should upload VRM or click "Skip" after initialization completes
- DO NOT proceed to screenshot/console checks until user confirms ready

### 5. Visual Verification

```
mcp__claude-in-chrome__computer(
  action: "screenshot",
  tabId: XXX
)
```

- Check if particles are visible
- Verify torus geometry is rendered
- Look for visual artifacts or errors

### 6. Check Console Errors

```
mcp__claude-in-chrome__read_console_messages(
  tabId: XXX,
  pattern: "Error|TypeError|Ruby|undefined",
  onlyErrors: true
)
```

- Always provide `pattern` to filter relevant messages
- Focus on Ruby-related errors first

### 7. Add Debug Output to Code

When you need to inspect variables:

1. Edit index.html to add `console.log` statements
2. Reload the page (repeat steps 3-5)
3. Read console messages again

**IMPORTANT**: Output one variable at a time to avoid exceptions that fail the entire logging block.

Example:
```ruby
# Good: one value per log
JS.global[:console].log("[DEBUG] typeof=#{js_obj.typeof}")
JS.global[:console].log("[DEBUG] value=#{some_value}")

# Bad: multiple values can fail if one throws
JS.global[:console].log("[DEBUG] typeof=#{js_obj.typeof} value=#{some_value}")
```

### 8. Dynamic Debugging with JavaScript

```
mcp__claude-in-chrome__javascript_tool(
  tabId: XXX,
  text: "console.log('[DEBUG]', window.audioContext.state)"
)
```

- Inspect runtime state without editing files
- Access browser APIs and global objects

## Common Error Patterns

### VRM Model Not Animating (Bone Movements Missing)

**Symptoms**:
- VRM model displays correctly but remains static
- No bone rotation/dance movements despite audio playing
- Particles and effects work normally

**Diagnosis Steps**:

1. **Check window.currentVRM accessibility**:
```javascript
mcp__claude-in-chrome__javascript_tool(
  tabId: XXX,
  text: "typeof window.currentVRM"
)
```
Expected: `"object"` (if VRM loaded) or `"undefined"` (if not loaded or inaccessible)

2. **Verify VRM update logs**:
```
mcp__claude-in-chrome__read_console_messages(
  tabId: XXX,
  pattern: "VRM rot|Initialization complete",
  limit: 10
)
```
Expected: Logs like `"VRM rot: h=0.349 s=0.003 c=0.07 hY=0.0"` appearing every 60 frames

3. **Capture bone movement evidence**:
```
# Take first screenshot
mcp__claude-in-chrome__computer(action: "screenshot", tabId: XXX)

# Wait 3-5 seconds
mcp__claude-in-chrome__computer(action: "wait", duration: 3, tabId: XXX)

# Take second screenshot
mcp__claude-in-chrome__computer(action: "screenshot", tabId: XXX)
```
Compare VRM rot values in debug text - rotation values should change between screenshots

**Root Cause**: `let`-scoped variables in JavaScript are not accessible via `window` object

**Example Problem**:
```javascript
// index.html
let currentVRM = null;  // ← Not accessible as window.currentVRM

// Later in VRM load callback
currentVRM = gltf.userData.vrm;  // ← Sets local variable only

// Ruby side (main.rb)
has_vrm = JS.global[:currentVRM].typeof.to_s != "undefined"  # ← Always "undefined"!
```

**Solution**: Explicitly expose to window object
```javascript
// After setting local variable
currentVRM = gltf.userData.vrm;
window.currentVRM = currentVRM;  // ← Add this line
```

### TypeError: Cannot set properties of undefined (setting 'aspect')

**Symptoms**:
- Mass error logs during page load
- Error: `TypeError: Cannot set properties of undefined (setting 'aspect')`
- Errors occur before Three.js initialization completes

**Root Cause**: Window resize event fires before `camera` object is initialized

**Diagnosis**:
```
mcp__claude-in-chrome__read_console_messages(
  tabId: XXX,
  pattern: "aspect|resize",
  onlyErrors: true,
  limit: 5
)
```

**Solution**: Add initialization check to resize handler
```javascript
// Before fix
window.addEventListener('resize', function() {
  camera.aspect = width / height;  // ← Crashes if camera undefined
  // ...
});

// After fix
window.addEventListener('resize', function() {
  if (!camera || !renderer || !composer) return;  // ← Add this check

  camera.aspect = width / height;
  // ...
});
```

### TypeError: Function.prototype.apply was called on undefined

**Root Cause**: Bug in `JS::Object#call()` method (js gem 2.8.1)

**Solution**: Use `method_missing` pattern instead
```ruby
# Wrong
js_func = JS.global[:updateParticles]
js_func.call(a, b)  # ← TypeError

# Correct
JS.global.updateParticles(a, b)  # ← Works via method_missing
```

### NoMethodError: undefined method `class' for #<JS::Object>

**Root Cause**: `JS::Object` inherits from `BasicObject`, doesn't have `.class`

**Solution**: Use `.typeof` or convert to Ruby types
```ruby
# Wrong
js_obj.class  # ← NoMethodError

# Correct
js_obj.typeof  # ← "function"
js_obj.to_s    # ← Convert to Ruby String
```

### AudioContext remains suspended

**Root Cause**: Chrome's autoplay policy

**Solution**: Explicitly call `audioContext.resume()`
```ruby
# Add after AudioContext creation
JS.global[:audioContext].resume
```

**Fallback**: Add click event handler to resume
```javascript
document.addEventListener('click', () => {
  if (audioContext.state === 'suspended') {
    audioContext.resume();
  }
}, { once: true });
```

## Programmatic Error Monitoring Script

When DevTools cannot be opened, inject error monitoring:

```javascript
mcp__claude-in-chrome__javascript_tool(
  tabId: XXX,
  text: `
    window._errorCount = 0;
    window._errorMessages = [];
    const origError = console.error;
    console.error = function(...args) {
      window._errorCount++;
      if (window._errorMessages.length < 5) {
        window._errorMessages.push(
          args.map(a => String(a).substring(0, 200)).join(' ')
        );
      }
      origError.apply(console, args);
    };
    'Error monitoring installed';
  `
)
```

Later, check results:
```javascript
mcp__claude-in-chrome__javascript_tool(
  tabId: XXX,
  text: `JSON.stringify({
    errorCount: window._errorCount,
    errors: window._errorMessages
  })`
)
```

## Three.js / WebGL Debugging

### Verify WebGL Context

```javascript
mcp__claude-in-chrome__javascript_tool(
  tabId: XXX,
  text: `
    const canvas = document.querySelector('canvas');
    const gl = canvas?.getContext('webgl2') || canvas?.getContext('webgl');
    JSON.stringify({
      hasCanvas: !!canvas,
      hasContext: !!gl,
      renderer: gl?.getParameter(gl.VERSION) || 'N/A'
    });
  `
)
```

### Check Scene Object Counts

```javascript
mcp__claude-in-chrome__javascript_tool(
  tabId: XXX,
  text: `JSON.stringify({
    sceneChildren: scene?.children.length || 0,
    particles: particleSystem?.children.length || 0,
    geometry: torusMesh?.geometry.type || 'N/A'
  })`
)
```

## Best Practices

1. **Always use Chrome MCP tools** - Never ask user to manually check browser
2. **Wait for user action** - Let user upload VRM or click skip after Ruby WASM loads
3. **Use pattern parameter** in `read_console_messages` to filter noise
4. **Screenshot first** for visual confirmation before diving into logs
5. **One debug variable per log** to avoid cascading exceptions
6. **Cache-bust URLs** with `?nocache=<random>` for reliable testing
