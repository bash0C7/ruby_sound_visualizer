# Integrated Batch Plan: Restructure + Migration + Observability + DevTool Interface

## Overview

This plan integrates 4 tasks from tasks.md into a single coherent execution sequence:

1. **Ruby class restructure** - Extract concerns from main.rb, fix global state
2. **Console log visibility** - Structured log buffer for Chrome MCP access
3. **DevTool interface** - Dynamic config changes from Chrome DevTools console
4. **JS-to-Ruby migration** - Move remaining JS logic to Ruby

## Dependency Graph

```
config-centralization [DONE]
  |
  v
ruby-class-restructure -------> js-to-ruby-migration
  |                                    |
  v                                    v
devtool-interface              (keyboard + FPS + debug)

console-log-visibility (independent)
```

## Execution Phases

### Phase 1: Ruby Class Restructure - Extract from main.rb

**Goal:** Reduce main.rb from 250 lines to ~60 lines (thin orchestrator).

#### 1a. Create `src/ruby/keyboard_handler.rb`

Extract all keyboard callback logic from main.rb (lines 175-241).

```ruby
# keyboard_handler.rb
class KeyboardHandler
  def initialize
    register_callbacks
  end

  def register_callbacks
    JS.global[:rubySetColorMode] = method(:handle_color_mode)
    JS.global[:rubyAdjustSensitivity] = method(:handle_sensitivity)
    JS.global[:rubyShiftHue] = method(:handle_hue_shift)
    JS.global[:rubyAdjustMaxBrightness] = method(:handle_brightness)
    JS.global[:rubyAdjustMaxLightness] = method(:handle_lightness)
  end

  # Each handler method wraps a lambda with error handling
end
```

**Files changed:**
- NEW: `src/ruby/keyboard_handler.rb`
- MODIFY: `src/ruby/main.rb` - remove keyboard lambdas
- MODIFY: `index.html` - add script tag (REQUIRES USER APPROVAL)

**Tests:**
- `test/test_keyboard_handler.rb` - dispatch correctness, Config value changes

---

#### 1b. Create `src/ruby/debug_formatter.rb`

Extract all debug text formatting from main.rb (lines 131-158).

```ruby
# debug_formatter.rb
class DebugFormatter
  def format_debug_text(analysis, beat)
    # Mode, frequencies, HSV, BPM, beat indicator
  end

  def format_param_text
    # Sensitivity, MaxBrightness, MaxLightness
  end

  def format_key_guide
    # Static key guide string
  end
end
```

**Files changed:**
- NEW: `src/ruby/debug_formatter.rb`
- MODIFY: `src/ruby/main.rb` - delegate to DebugFormatter
- MODIFY: `index.html` - add script tag (REQUIRES USER APPROVAL)

**Tests:**
- `test/test_debug_formatter.rb` - format output, edge cases (zero energy, etc.)

---

#### 1c. Create `src/ruby/bpm_estimator.rb`

Extract BPM calculation from main.rb (lines 100-123).

```ruby
# bpm_estimator.rb
class BPMEstimator
  def initialize
    @beat_times = []
    @estimated_bpm = 0
    @frame_count = 0
  end

  attr_reader :estimated_bpm

  def record_beat(frame_number)
    @beat_times << frame_number
    @beat_times = @beat_times.last(16) if @beat_times.length > 16
    recalculate
  end

  def tick
    @frame_count += 1
  end

  private

  def recalculate
    return if @beat_times.length < 3
    # Interval-based BPM calculation
  end
end
```

**Files changed:**
- NEW: `src/ruby/bpm_estimator.rb`
- MODIFY: `src/ruby/main.rb` - delegate to BPMEstimator, remove $beat_times/$estimated_bpm
- MODIFY: `index.html` - add script tag (REQUIRES USER APPROVAL)

**Tests:**
- `test/test_bpm_estimator.rb` - BPM calculation, edge cases, ring buffer overflow

---

#### 1d. Slim down main.rb

After extraction, main.rb should contain only:
1. URL parameter parsing -> Config
2. Object initialization (AudioAnalyzer, EffectManager, etc.)
3. Single `rubyUpdateVisuals` callback (calls extracted classes)
4. Frame count management

Globals eliminated:
- `$beat_times` -> BPMEstimator
- `$estimated_bpm` -> BPMEstimator
- `$frame_count` -> instance variable in orchestrator or BPMEstimator

Globals remaining (acceptable for ruby.wasm top-level scope):
- `$initialized` - init flag
- `$audio_analyzer`, `$effect_manager`, `$vrm_dancer`, `$vrm_material_controller` - top-level instances

---

### Phase 2: Ruby Class Restructure - ColorPalette Instance

**Goal:** Convert ColorPalette from class-method + class-variable pattern to instance-based.

#### Changes

```ruby
# BEFORE (class variables, global mutable state)
ColorPalette.set_hue_mode(1)
color = ColorPalette.frequency_to_color(analysis)

# AFTER (instance, owned by EffectManager)
palette = ColorPalette.new
palette.hue_mode = 1
color = palette.frequency_to_color(analysis)
```

**Files changed:**
- MODIFY: `src/ruby/color_palette.rb` - `@@` -> `@`, add `initialize`, instance methods
- MODIFY: `src/ruby/effect_manager.rb` - create and own ColorPalette instance, pass to sub-controllers
- MODIFY: `src/ruby/particle_system.rb` - receive palette instance via `update(analysis, palette:)`
- MODIFY: `src/ruby/geometry_morpher.rb` - receive palette instance via `update(analysis, palette:)`
- MODIFY: `src/ruby/keyboard_handler.rb` - receive palette reference for mode changes
- MODIFY: `src/ruby/debug_formatter.rb` - receive palette for HSV display
- MODIFY: `src/ruby/main.rb` - pass palette through call chain

**Tests:**
- Update existing tests
- New instance-based ColorPalette tests

**Risk:** High - touches 7 files, changes interfaces. Execute carefully with test verification after each file.

---

### Phase 3: Console Log Visibility

**Goal:** Make browser console logs accessible to Claude Code via Chrome MCP tools.

#### 3a. Add logBuffer to index.html

Add structured ring buffer before any other scripts.

```javascript
// Log buffer for Chrome MCP access (inserted early in <script>)
window.logBuffer = {
  entries: [],
  maxSize: 500,
  add(level, source, message) {
    this.entries.push({
      ts: new Date().toISOString().substr(11, 12),
      level, source, message
    });
    if (this.entries.length > this.maxSize) {
      this.entries = this.entries.slice(-this.maxSize);
    }
  },
  getLast(n) { return this.entries.slice(-(n || 20)); },
  getErrors() { return this.entries.filter(e => e.level === 'error'); },
  getRuby() { return this.entries.filter(e => e.source === 'ruby'); },
  getJS() { return this.entries.filter(e => e.source === 'js'); },
  clear() { this.entries = []; },
  dump() {
    return this.entries.map(e =>
      `${e.ts} [${e.level}][${e.source}] ${e.message}`
    ).join('\n');
  }
};
```

#### 3b. Console override

```javascript
// Intercept console methods
['log', 'warn', 'error'].forEach(method => {
  const original = console[method].bind(console);
  console[method] = function(...args) {
    original(...args);
    const msg = args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
    const source = msg.startsWith('[Ruby]') ? 'ruby' :
                   msg.startsWith('[JS]') ? 'js' :
                   msg.startsWith('[DEBUG') ? 'debug' : 'other';
    window.logBuffer.add(method === 'log' ? 'info' : method, source, msg);
  };
});
```

#### 3c. Enhanced JSBridge

Add structured log support to JSBridge:

```ruby
module JSBridge
  def self.log(message, source: 'ruby')
    JS.global[:console].log("[Ruby] #{message}")
  end
  # No additional changes needed - console override captures everything
end
```

**Files changed:**
- MODIFY: `index.html` - add logBuffer + console override (REQUIRES USER APPROVAL)
- MODIFY: `src/ruby/js_bridge.rb` - minor: ensure all logs have [Ruby] prefix (already done)

**Tests:**
- Manual verification with Chrome MCP (local session required for final validation)
- JavaScript unit test for logBuffer can be added inline

---

### Phase 4: DevTool Console Interface

**Goal:** Allow dynamic config changes from Chrome DevTools console.

#### 4a. Add ConfigInterface to config.rb

```ruby
module Config
  # ... existing constants and accessors ...

  # Runtime-mutable key registry for DevTool interface
  MUTABLE_KEYS = {
    'sensitivity' => { min: 0.05, max: 10.0, type: :float },
    'max_brightness' => { min: 0, max: 255, type: :int },
    'max_lightness' => { min: 0, max: 255, type: :int }
  }.freeze

  def self.set_by_key(key, value)
    key_str = key.to_s
    spec = MUTABLE_KEYS[key_str]
    return "Unknown key: #{key_str}. Use list() to see available keys." unless spec

    val = spec[:type] == :int ? value.to_i : value.to_f
    val = [[val, spec[:min]].max, spec[:max]].min

    case key_str
    when 'sensitivity' then self.sensitivity = val
    when 'max_brightness' then self.max_brightness = val
    when 'max_lightness' then self.max_lightness = val
    end

    "#{key_str} = #{val}"
  end

  def self.get_by_key(key)
    case key.to_s
    when 'sensitivity' then sensitivity
    when 'max_brightness' then max_brightness
    when 'max_lightness' then max_lightness
    else "Unknown key: #{key}"
    end
  end

  def self.list_keys
    MUTABLE_KEYS.map { |k, spec|
      current = get_by_key(k)
      "#{k}: #{current} (#{spec[:min]}..#{spec[:max]})"
    }.join("\n")
  end

  def self.reset_runtime
    self.sensitivity = 1.0
    self.max_brightness = 255
    self.max_lightness = 255
    "All runtime values reset to defaults"
  end

  def self.register_devtool_callbacks
    JS.global[:rubyConfigSet] = lambda { |key, value|
      begin
        result = Config.set_by_key(key.to_s, value)
        JS.global[:console].log("[Config] #{result}")
        result
      rescue => e
        JS.global[:console].error("[Config] Error: #{e.message}")
      end
    }
    JS.global[:rubyConfigGet] = lambda { |key|
      Config.get_by_key(key.to_s)
    }
    JS.global[:rubyConfigList] = lambda {
      result = Config.list_keys
      JS.global[:console].log("[Config]\n#{result}")
      result
    }
    JS.global[:rubyConfigReset] = lambda {
      result = Config.reset_runtime
      JS.global[:console].log("[Config] #{result}")
      result
    }
  end
end
```

#### 4b. JS convenience wrapper in index.html

```javascript
// DevTool console interface (after Ruby VM is ready)
window.rubyConfig = {
  set: (key, value) => window.rubyConfigSet?.(key, value) ?? 'Ruby VM not ready',
  get: (key) => window.rubyConfigGet?.(key) ?? 'Ruby VM not ready',
  list: () => window.rubyConfigList?.() ?? 'Ruby VM not ready',
  reset: () => window.rubyConfigReset?.() ?? 'Ruby VM not ready',
  help: () => console.log('Usage: rubyConfig.set(key, value) | .get(key) | .list() | .reset()')
};
```

#### 4c. Register callbacks in main.rb

```ruby
# In main.rb initialization
Config.register_devtool_callbacks
JSBridge.log "DevTool interface ready: rubyConfig.set/get/list/reset"
```

**Files changed:**
- MODIFY: `src/ruby/config.rb` - add MUTABLE_KEYS, set_by_key, get_by_key, list_keys, reset_runtime, register_devtool_callbacks
- MODIFY: `index.html` - add rubyConfig wrapper (REQUIRES USER APPROVAL)
- MODIFY: `src/ruby/main.rb` - call Config.register_devtool_callbacks

**Tests:**
- `test/test_config.rb` - add tests for set_by_key, get_by_key, list_keys, reset_runtime
- Manual verification from Chrome DevTools (local session)

---

### Phase 5: JS-to-Ruby Migration - Keyboard Consolidation

**Goal:** Replace ~80 lines of JS keyboard dispatch with a single `rubyHandleKey(key)` call.

#### 5a. Simplify JS keyboard handler

```javascript
// BEFORE: ~80 lines of if/else dispatching to individual Ruby functions
// AFTER: ~5 lines
window.addEventListener('keydown', function(event) {
  if (window.rubyHandleKey) {
    try {
      window.rubyHandleKey(event.key);
    } catch (error) {
      console.error('[JS] Error calling rubyHandleKey:', error);
    }
  }
});
```

#### 5b. Full keyboard dispatch in Ruby

Extend `keyboard_handler.rb` to handle all keys:

```ruby
class KeyboardHandler
  def initialize(palette:, camera_step: 0.5)
    @palette = palette
    @camera_step = camera_step
    register_master_callback
  end

  private

  def register_master_callback
    JS.global[:rubyHandleKey] = lambda do |key|
      begin
        handle_key(key.to_s)
      rescue => e
        JSBridge.error "KeyboardHandler: #{e.message}"
      end
    end
  end

  def handle_key(key)
    case key
    when '0'..'3' then handle_color_mode(key.to_i)
    when '4', '5' then handle_hue_shift(key == '4' ? -5 : 5)
    when '6', '7' then handle_brightness(key == '6' ? -5 : 5)
    when '8', '9' then handle_lightness(key == '8' ? -5 : 5)
    when '-'       then handle_sensitivity(-0.05)
    when '+', '='  then handle_sensitivity(0.05)
    when 'a', 's', 'w', 'x', 'q', 'z' then handle_camera(key)
    when 'd', 'f', 'e', 'c' then handle_camera_rotation(key)
    end
  end
  # ... individual handler methods
end
```

#### 5c. Remove per-function Ruby callbacks

Remove individual `rubySetColorMode`, `rubyAdjustSensitivity`, etc. from JS.global.
Replace with single `rubyHandleKey`.

Also remove JS-side `setupCameraControls()` function and its `keydown` listener.

**Files changed:**
- MODIFY: `src/ruby/keyboard_handler.rb` - add master dispatch, camera controls
- MODIFY: `index.html` - replace ~80 lines with ~5 lines (REQUIRES USER APPROVAL)
- MODIFY: `src/ruby/main.rb` - remove individual callback registrations

**Tests:**
- `test/test_keyboard_handler.rb` - test dispatch for each key

---

### Phase 6: JS-to-Ruby Migration - FPS & Debug Info

**Goal:** Move FPS calculation and DOM update orchestration to Ruby.

#### 6a. FPS calculation in Ruby

```ruby
# In main update loop
class FrameCounter
  def initialize
    @frame_count = 0
    @last_report_time = nil
    @current_fps = 0
  end

  attr_reader :current_fps, :frame_count

  def tick(timestamp_ms)
    @frame_count += 1
    @last_report_time ||= timestamp_ms

    elapsed = timestamp_ms - @last_report_time
    if elapsed >= 1000
      @current_fps = (@frame_count * 1000.0 / elapsed).round(0)
      @frame_count = 0
      @last_report_time = timestamp_ms
      true  # report ready
    else
      false
    end
  end
end
```

#### 6b. JS animate() simplification

```javascript
// BEFORE: FPS calculation, debug DOM updates in JS
// AFTER: Pass timestamp to Ruby, Ruby handles everything
function animate() {
  requestAnimationFrame(animate);
  const now = Date.now();
  window._animDeltaTime = (now - animLastTime) / 1000;
  animLastTime = now;

  if (analyser) {
    analyser.getByteFrequencyData(dataArray);
    if (window.rubyUpdateVisuals) {
      try {
        window.rubyUpdateVisuals(Array.from(dataArray), now);
      } catch (error) {
        console.error('[JS] Error calling Ruby update:', error);
      }
    }
  }

  if (currentVRM) currentVRM.update(window._animDeltaTime);
  if (composer) composer.render();
}
```

Ruby update callback receives timestamp and handles FPS + debug DOM updates.

**Files changed:**
- NEW: `src/ruby/frame_counter.rb` (or integrate into bpm_estimator.rb)
- MODIFY: `index.html` - simplify animate() (REQUIRES USER APPROVAL)
- MODIFY: `src/ruby/main.rb` - use FrameCounter, handle DOM updates

**Tests:**
- `test/test_frame_counter.rb` (or test_bpm_estimator.rb)

---

## Execution Summary

| Phase | Task | New Files | Modified Files | Risk | index.html |
|-------|------|-----------|---------------|------|------------|
| 1a | KeyboardHandler extraction | 1 (+test) | main.rb | Low | Yes |
| 1b | DebugFormatter extraction | 1 (+test) | main.rb | Low | Yes |
| 1c | BPMEstimator extraction | 1 (+test) | main.rb | Low | Yes |
| 1d | Slim main.rb | 0 | main.rb | Low | No |
| 2 | ColorPalette instance | 0 (+test updates) | 7 files | High | No |
| 3 | Console log visibility | 0 | index.html, js_bridge.rb | Low | Yes |
| 4 | DevTool interface | 0 (+test updates) | config.rb, main.rb | Low | Yes |
| 5 | JS keyboard consolidation | 0 | keyboard_handler.rb, index.html | Medium | Yes |
| 6 | FPS & debug migration | 1 (+test) | index.html, main.rb | Medium | Yes |

**Total new Ruby files:** 4 (keyboard_handler.rb, debug_formatter.rb, bpm_estimator.rb, frame_counter.rb)
**Total new test files:** 4-5
**Total index.html changes:** 6 separate modifications (batch into single approval)

## Critical Rules

1. **TDD**: Red -> Green -> Refactor for every phase
2. **index.html approval**: All index.html changes batched and require explicit user approval
3. **Test after each phase**: `bundle exec rake test` must pass before proceeding
4. **One phase at a time**: Complete and verify each phase before starting next
5. **Commit per phase**: Each phase gets its own commit for easy rollback

## Phase Grouping for Commits

- **Commit 1:** Phase 1a-1d (main.rb extraction) + index.html script tags
- **Commit 2:** Phase 2 (ColorPalette instance conversion)
- **Commit 3:** Phase 3 (Console log visibility)
- **Commit 4:** Phase 4 (DevTool interface)
- **Commit 5:** Phase 5 (JS keyboard consolidation)
- **Commit 6:** Phase 6 (FPS & debug migration)

## What Stays in JavaScript (final state after all phases)

After all migrations, JavaScript retains ONLY:
1. Three.js imports and global registration
2. `initAudio()` - Web Audio API setup
3. `initThree()` - Three.js scene/camera/renderer creation
4. `animate()` - requestAnimationFrame + getByteFrequencyData + composer.render (thin)
5. `updateParticles/Geometry/Bloom/Camera/VRM/VRMMaterial` - Apply Ruby-computed data to WebGL
6. `loadVRMFile()` - GLTF/VRM parsing
7. `waitForVRMFile()` - File upload UI
8. Window resize handler
9. Console override + logBuffer (Phase 3)
10. `rubyConfig` wrapper (Phase 4)

Everything else (keyboard dispatch, FPS, debug formatting, BPM) moves to Ruby.
