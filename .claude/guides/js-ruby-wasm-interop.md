# JavaScript and ruby.wasm Interop Guide

Interop patterns used by this project between Ruby (WASM) and browser JavaScript.

## Table of Contents

1. [Overview](#overview)
2. [Calling JavaScript from Ruby](#calling-javascript-from-ruby)
3. [Calling Ruby from JavaScript](#calling-ruby-from-javascript)
4. [Data Type Conversion](#data-type-conversion)
5. [JS::Object Pitfalls](#jsobject-pitfalls)
6. [Error Handling](#error-handling)
7. [Debugging Techniques](#debugging-techniques)
8. [Performance Considerations](#performance-considerations)
9. [Known Issues and Workarounds](#known-issues-and-workarounds)
10. [References](#references)

## Overview

The app runs Ruby logic in the browser and uses the `js` bridge to communicate with JavaScript APIs.

```text
Ruby (WASM)
  |- AudioAnalyzer / EffectManager / VJPad / ...
  |- JSBridge
  v
JavaScript (window)
  |- Three.js updates
  |- Web Audio / Web Serial / DOM
```

Core idea:
- Ruby computes visual state.
- JavaScript applies rendering and browser API side effects.

## Calling JavaScript from Ruby

### Global function calls

```ruby
JS.global.updateParticles(positions, colors, avg_size, avg_opacity)
JS.global.updateGeometry(scale, rotation, emissive, color)
JS.global.updateBloom(strength, threshold)
```

This project centralizes most calls inside `JSBridge`.

### Property read/write

```ruby
search = JS.global[:location][:search].to_s
JS.global[:debugInfoText] = text
JS.global[:fpsText] = "FPS: 60"
```

### JavaScript-side functions currently called by Ruby

Main rendering and UI:
- `updateParticles`
- `updateGeometry`
- `updateBloom`
- `updateCamera`
- `updateParticleRotation`
- `updateVRM`
- `updateVRMMaterial`
- `penDrawStrokes`
- `wordartRender`

Serial and input glue:
- `serialConnect`, `serialDisconnect`, `serialSend`
- `toggleTabCapture`, `setMicMute`

## Calling Ruby from JavaScript

Ruby registers callbacks on `window` using lambdas.

### Main callbacks registered in `main.rb`

- `rubyUpdateVisuals(freq_array, timestamp)`
- `rubyExecPrompt(input)`
- `rubyHandleKey(key)` (registered by `KeyboardHandler`)
- `rubySerialOnConnect(baud)`
- `rubySerialOnDisconnect()`
- `rubySerialOnReceive(data)`
- `rubyPenDown(x, y, buttons)`
- `rubyPenMove(x, y)`
- `rubyPenUp()`
- `rubyConfigSet(key, value)`
- `rubyConfigGet(key)`
- `rubyConfigList()`
- `rubyConfigReset()`
- `rubySnapshotEncode(cr, cth, cph)`
- `rubySnapshotApply(query_string)`

JavaScript calls these directly from keyboard handlers, control panel UI, and animation loop.

## Data Type Conversion

### Ruby to JavaScript

Common automatic conversions:
- `Float`/`Integer` -> JS `Number`
- `String` -> JS `String`
- `Array` -> array-like object consumable by `Array.from(...)`
- `Hash` -> object-like structure

### JavaScript to Ruby

Incoming values are usually `JS::Object` wrappers and should be converted explicitly.

```ruby
key = js_key.to_s
num = js_value.to_f
arr = js_array.to_a
```

### Recommended conversion style in this codebase

- Convert early at callback boundaries.
- Keep pure Ruby internals free from `JS::Object` values.
- Return simple scalar/string values from Ruby callbacks where possible.

## JS::Object Pitfalls

`JS::Object` behaves differently from normal Ruby objects.

Practical rules:
- Do not assume `.class`, `.inspect`, or type predicates behave like regular Ruby objects.
- Prefer `.typeof`, `.to_s`, `.to_f`, `.to_i`, `.to_a`.
- Convert before regex/string logic.

Example:

```ruby
# Good
search = JS.global[:location][:search].to_s
match = search.match(/sensitivity=([0-9.]+)/)
```

## Error Handling

### Callback safety

All high-frequency callbacks should protect themselves:

```ruby
JS.global[:rubyUpdateVisuals] = lambda do |freq_array, timestamp|
  begin
    # frame work
  rescue => e
    JSBridge.error "Error in rubyUpdateVisuals: #{e.class} #{e.message}"
  end
end
```

### JSBridge guard pattern

`JSBridge` methods wrap JS calls with `rescue` and log to browser console to avoid hard crashes in the loop.

## Debugging Techniques

### Log channels

- Ruby logs: `JSBridge.log`, `JSBridge.error`
- JS logs: `console.log`, `console.error`
- Central ring buffer: `window.logBuffer`

Useful log buffer commands:

```javascript
window.logBuffer.getLast(20)
window.logBuffer.getErrors()
window.logBuffer.getRuby()
window.logBuffer.getJS()
window.logBuffer.dump()
```

### DevTools runtime tuning

Use the wrapper object in JS console:

```javascript
window.rubyConfig.set('sensitivity', 2.0)
window.rubyConfig.get('sensitivity')
window.rubyConfig.list()
window.rubyConfig.reset()
```

### Snapshot debugging

- Encode current runtime/camera state: `rubySnapshotEncode(...)`
- Apply state from query string: `rubySnapshotApply('?v=1&...')`

## Performance Considerations

### Boundary crossing cost

Ruby <-> JS calls are expensive compared with pure local operations.

Current strategy:
- Compute frame state in Ruby once.
- Push compact outputs to JS via a small fixed call set.
- Avoid per-particle per-call JS bridging.

### Data volume hotspots

Most expensive payload each frame:
- particle positions/colors arrays

Mitigations used:
- Single bulk call (`updateParticles`)
- Ruby-side average size/opacity precomputed

### Frame-loop discipline

- Keep heavy math in Ruby modules.
- Keep JS render updates thin and imperative.
- Throttle textual DOM refresh.

## Known Issues and Workarounds

### Function reference invocation quirks

Calling function references through generic wrappers can behave unexpectedly in some bridge contexts.

Recommended style:
- Prefer direct method-style calls (`JS.global.someFunction(...)`) over indirect call chains.

### AudioContext suspended state

Browsers may start `AudioContext` as suspended.

Workaround in this project:
- Attempt resume during init.
- Add user-click fallback resume listener.

### Browser feature availability

Some APIs are browser-dependent:
- Web Serial API support
- Tab capture permissions/flows
- Window placement API for perf view

Always provide a fallback behavior path.

## References

- [ruby.wasm Docs](https://ruby.github.io/ruby.wasm/)
- [ruby.wasm JS API](https://ruby.github.io/ruby.wasm/JS.html)
- [ruby.wasm GitHub](https://github.com/ruby/ruby.wasm)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API)
