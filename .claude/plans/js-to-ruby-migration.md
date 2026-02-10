# Plan: Minimize JavaScript, Migrate Logic to Ruby

## Goal

Move as much logic as possible from JavaScript to Ruby, leaving JavaScript as a thin WebGL/Web Audio API bridge only.

## Current State

`index.html` contains approximately 770 lines of JavaScript (lines 134-893) with these functions:

### JavaScript functions that contain logic (migration candidates)

1. **`animate()`** (~30 lines): Main render loop with FPS calculation, frequency data extraction, Ruby callback invocation, debug info DOM updates
2. **`updateDebugInfo()`** (~15 lines): Reads Ruby-formatted strings and updates DOM elements
3. **Keyboard handler** (~40 lines): `document.addEventListener('keydown', ...)` dispatches to Ruby callbacks
4. **VRM loading** (~50 lines): `loadVRM()` function with GLTF/VRM parsing
5. **`updateParticles()`** (~20 lines): Applies Ruby-computed positions/colors to Three.js BufferGeometry
6. **`updateGeometry()`** (~15 lines): Applies Ruby-computed scale/rotation/color to Three.js Mesh
7. **`updateBloom()`** (~5 lines): Applies Ruby-computed bloom params
8. **`updateCamera()`** (~15 lines): Applies Ruby-computed camera position + shake
9. **`updateVRM()`** (~25 lines): Applies Ruby-computed bone rotations to VRM
10. **`updateVRMMaterial()`** (~15 lines): Applies emissive settings to VRM materials

### JavaScript functions that must stay in JS (WebGL/DOM API)

- `initAudio()`: Web Audio API (getUserMedia, AnalyserNode)
- `initThree()`: Three.js scene/camera/renderer/material creation
- Buffer attribute updates (Float32Array manipulation for WebGL)
- `renderer.render()` / `composer.render()` calls
- Window resize handler
- DOM manipulation for loading screen

## Migration Strategy

### Priority 1: Move FPS calculation to Ruby
Currently in `animate()`. Move to Ruby, return via global variable.

### Priority 2: Move keyboard dispatch logic to Ruby
Currently JS does keycode mapping and calls specific Ruby functions. Instead:
- JS sends raw keycode to single Ruby handler
- Ruby does all dispatch logic (already partially done)

### Priority 3: Move VRM bone application logic to Ruby-directed JS
Currently `updateVRM()` has rotation application logic. Instead:
- Ruby computes complete quaternion data
- JS just applies raw quaternion values (no logic)

### Priority 4: Move debug DOM updates to Ruby-directed JS
Currently `updateDebugInfo()` reads multiple global variables. Instead:
- Ruby sets a single formatted HTML string
- JS just does `element.innerHTML = rubyFormattedHTML`

### Not migrated (must stay in JS)
- Three.js object creation and WebGL rendering
- Web Audio API initialization
- Float32Array buffer manipulation (performance-critical)
- DOM event listeners (only the raw event capture)

## Changes Required

### Phase 1: Keyboard handling consolidation
- **index.html**: Simplify keydown handler to call single `window.rubyHandleKey(keyCode)`
- **New `src/ruby/keyboard_handler.rb`** (from ruby-class-restructure plan): Full dispatch logic

### Phase 2: FPS and frame management
- **src/ruby/main.rb**: Calculate FPS from timestamps passed by JS
- **index.html**: Pass timestamp to `rubyUpdateVisuals` instead of calculating FPS in JS

### Phase 3: Debug info simplification
- **index.html**: Reduce `updateDebugInfo()` to single innerHTML assignment
- **src/ruby/debug_formatter.rb**: Output complete HTML-formatted string

### Phase 4: VRM update simplification
- **index.html**: Reduce `updateVRM()` to raw quaternion application
- **src/ruby/vrm_dancer.rb**: Compute quaternions instead of Euler angles

## TDD Approach

Each phase:
1. Write tests for the Ruby-side replacement
2. Implement Ruby logic
3. Simplify corresponding JS function
4. Verify with Chrome MCP (local session)

## Estimated Scope

- Files: `index.html` (requires user approval), multiple Ruby files
- Risk: High (changes JS-Ruby boundary, needs careful testing)
- Recommendation: Execute one phase per session
- Dependency: Overlaps with ruby-class-restructure (keyboard_handler, debug_formatter)
