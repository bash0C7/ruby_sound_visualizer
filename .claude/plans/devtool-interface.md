# Plan: DevTool Console Interface for Dynamic Configuration

## Goal

Implement an interface that allows changing configuration values dynamically from Chrome DevTools console, using Ruby-JS interop.

## Current State

- Configuration changes require URL parameters or keyboard shortcuts
- No way to set arbitrary values from DevTools
- Keyboard shortcuts have fixed increments (e.g., sensitivity +/- 0.1, brightness +/- 5)

## Target Design

### JavaScript API (accessible from DevTools console)

```javascript
// In DevTools console:
rubyConfig.set('sensitivity', 2.5)
rubyConfig.get('sensitivity')         // => 2.5
rubyConfig.set('max_brightness', 128)
rubyConfig.list()                     // => prints all configurable values
rubyConfig.reset()                    // => reset all to defaults
rubyConfig.set('bloom_max_strength', 6.0)
rubyConfig.set('particle_friction', 0.9)
```

### Implementation Architecture

```
DevTools Console
  ↓ rubyConfig.set('key', value)
JavaScript bridge object (window.rubyConfig)
  ↓ Calls registered Ruby lambda
Ruby Config module
  ↓ Updates @@runtime_values hash
All classes read from Config at next frame
```

### Ruby Side

```ruby
# In Config module (or new ConfigInterface module)
module ConfigInterface
  MUTABLE_KEYS = {
    'sensitivity' => { default: 1.0, min: 0.05, max: 10.0 },
    'max_brightness' => { default: 255, min: 0, max: 255 },
    'max_lightness' => { default: 255, min: 0, max: 255 },
    'bloom_max_strength' => { default: 4.5, min: 0, max: 10.0 },
    'particle_friction' => { default: 0.86, min: 0.5, max: 0.99 },
    'impulse_decay' => { default: 0.82, min: 0.5, max: 0.99 },
    # ... more keys
  }

  def self.register_js_callbacks
    JS.global[:rubyConfigSet] = lambda { |key, value| set(key.to_s, value.to_f) }
    JS.global[:rubyConfigGet] = lambda { |key| get(key.to_s) }
    JS.global[:rubyConfigList] = lambda { list }
    JS.global[:rubyConfigReset] = lambda { reset }
  end
end
```

### JavaScript Side

```javascript
// Convenience wrapper object
window.rubyConfig = {
  set: (key, value) => window.rubyConfigSet(key, value),
  get: (key) => window.rubyConfigGet(key),
  list: () => window.rubyConfigList(),
  reset: () => window.rubyConfigReset()
};
```

## Dependencies

- Strongly depends on **config-centralization** task being completed first
- Runtime-mutable values must be in the Config module for this to work cleanly

## Changes Required

### 1. `src/ruby/config.rb` (or new `src/ruby/config_interface.rb`)
- Add runtime value registry with key/default/min/max definitions
- Add set/get/list/reset methods
- Register JS callbacks

### 2. `index.html` (requires user approval)
- Add `window.rubyConfig` convenience wrapper
- Add script tag for new Ruby file if separate

### 3. `src/ruby/main.rb`
- Call `ConfigInterface.register_js_callbacks` during initialization

## TDD Approach

1. Write tests for ConfigInterface set/get with validation (min/max clamping)
2. Write tests for list/reset
3. Implement Ruby side
4. Add JS wrapper
5. Manual test in DevTools (local session)

## Estimated Scope

- Files: `config.rb` (extend), `index.html`, `main.rb`
- Risk: Low (additive feature, no existing behavior changes)
- Prerequisite: config-centralization task
