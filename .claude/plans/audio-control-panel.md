# Audio Control Panel with Real-time Preview

## Overview

Add a slider-based control panel that overlays the visualizer, allowing real-time
adjustment of audio-reactive parameters with visual preview in without-VRM mode.

## Problem

Audio-reactive parameters (bloom intensity, particle burst sensitivity, frequency
band mappings) vary by environment (speaker setup, room acoustics, microphone).
Currently these are hardcoded constants requiring code changes to tune.

## Solution

1. Convert key audio-reactive constants to runtime-mutable parameters
2. Add a slider-based control panel UI to index.html
3. Show control panel on startup with live visualizer preview
4. Allow toggling the panel on/off during use

## Parameters to Expose

### Group 1: Master
| Parameter | Key | Range | Default | Step |
|-----------|-----|-------|---------|------|
| Sensitivity | `sensitivity` | 0.05-10.0 | 1.0 | 0.05 |

### Group 2: Bloom
| Parameter | Key | Range | Default | Step |
|-----------|-----|-------|---------|------|
| Base Strength | `bloom_base_strength` | 0.0-5.0 | 1.5 | 0.1 |
| Max Strength (Cap) | `max_bloom` | 0.0-10.0 | 4.5 | 0.1 |
| Energy Scale | `bloom_energy_scale` | 0.0-5.0 | 2.5 | 0.1 |
| Impulse Scale | `bloom_impulse_scale` | 0.0-3.0 | 1.5 | 0.1 |

### Group 3: Particles
| Parameter | Key | Range | Default | Step |
|-----------|-----|-------|---------|------|
| Explosion Prob. Base | `particle_explosion_base_prob` | 0.0-1.0 | 0.20 | 0.01 |
| Explosion Energy Scale | `particle_explosion_energy_scale` | 0.0-2.0 | 0.50 | 0.01 |
| Explosion Force Scale | `particle_explosion_force_scale` | 0.0-2.0 | 0.55 | 0.01 |
| Friction | `particle_friction` | 0.50-0.99 | 0.86 | 0.01 |

### Group 4: Rendering Caps
| Parameter | Key | Range | Default | Step |
|-----------|-----|-------|---------|------|
| Max Brightness | `max_brightness` | 0-255 | 255 | 1 |
| Max Lightness | `max_lightness` | 0-255 | 255 | 1 |
| Max Emissive | `max_emissive` | 0.0-10.0 | 2.0 | 0.1 |

### Group 5: Audio Response
| Parameter | Key | Range | Default | Step |
|-----------|-----|-------|---------|------|
| Visual Smoothing | `visual_smoothing` | 0.0-0.99 | 0.70 | 0.01 |
| Impulse Decay | `impulse_decay` | 0.50-0.99 | 0.82 | 0.01 |

## UX Design

### Startup Flow
1. User lands on page, sees "Upload VRM" / "Start without VRM" / "Capture Tab"
2. User clicks "Start without VRM"
3. Audio + Three.js initialize, visualizer starts as preview
4. Control panel appears as overlay on the right side
5. User adjusts sliders, sees effects in real-time
6. User clicks "Close" or presses `p` to dismiss panel
7. Can reopen panel anytime with `p` key

### Panel Layout
- Right-side overlay, ~320px wide, semi-transparent dark background
- Grouped sections with headers (collapsible)
- Each slider shows: label, current value, range input
- "Reset All" button at the bottom
- "Close" button at the top

### Keyboard Shortcut
- `p` key toggles control panel (consistent with existing keyboard controls)

## Implementation Phases

### Phase 1: Make Constants Mutable (TDD)
Files: `visualizer_policy.rb`, `test_visualizer_policy.rb`

1. Write failing tests for new mutable parameters
2. Add class variables with getters/setters for:
   - `bloom_base_strength`, `bloom_energy_scale`, `bloom_impulse_scale`
   - `particle_explosion_base_prob`, `particle_explosion_energy_scale`,
     `particle_explosion_force_scale`, `particle_friction`
   - `visual_smoothing`, `impulse_decay`
3. Add to `MUTABLE_KEYS` hash with ranges and defaults
4. Update `set_by_key`, `get_by_key`, `reset_runtime`
5. Run tests: all green

### Phase 2: Wire Mutable Values to Effect Controllers (TDD)
Files: `bloom_controller.rb`, `particle_system.rb`, `audio_analyzer.rb`,
       `effect_manager.rb`, existing test files

1. BloomController: Replace `BLOOM_BASE_STRENGTH` constant references with
   `VisualizerPolicy.bloom_base_strength` method calls, etc.
2. ParticleSystem: Replace `PARTICLE_EXPLOSION_*` and `PARTICLE_FRICTION`
   constant references with method calls
3. AudioAnalyzer: Replace `VISUAL_SMOOTHING_FACTOR` with method call
4. EffectManager: Replace `IMPULSE_DECAY_EFFECT` with method call
5. Keep original constants for backward compatibility (default values)
6. Run tests: all green

### Phase 3: Control Panel UI
File: `index.html`

1. Add CSS styles for the control panel overlay
2. Add HTML structure for grouped sliders
3. Add JS logic to:
   - Create sliders from parameter definitions
   - Wire slider `input` events to `rubyConfig.set()`
   - Read current values from `rubyConfig.get()` on panel open
   - Handle panel open/close toggle
4. Modify startup flow: show panel after "Start without VRM"
5. Add `p` key to keyboard handler for panel toggle

### Phase 4: VJ Pad Integration
Files: `vj_pad.rb`, `test_vj_pad.rb`

1. Add VJ Pad commands for new mutable parameters
2. Write tests for new commands
3. Sync slider values when VJ Pad commands change parameters

## Test Strategy

- Unit tests for all new VisualizerPolicy mutable parameters
- Unit tests for BloomController/ParticleSystem using mutable values
- Unit tests for new VJ Pad commands
- Manual browser testing for UI interaction (Chrome MCP if available)

## Files Modified

- `src/ruby/visualizer_policy.rb` - New mutable parameters
- `src/ruby/bloom_controller.rb` - Use mutable bloom params
- `src/ruby/particle_system.rb` - Use mutable particle params
- `src/ruby/audio_analyzer.rb` - Use mutable smoothing factor
- `src/ruby/effect_manager.rb` - Use mutable impulse decay
- `src/ruby/vj_pad.rb` - New commands for new params
- `index.html` - Control panel UI, startup flow, keyboard shortcut
- `test/test_visualizer_policy.rb` - New parameter tests
- `test/test_vj_pad.rb` - New command tests

## Risks and Mitigations

- **Performance**: Slider change events fire rapidly. Mitigation: sliders
  update Ruby config which is just a class variable setter, negligible cost.
- **Constants still referenced**: Some code may reference old constant names.
  Mitigation: Keep constants as default values, change active references to method calls.
- **Test breakage**: Existing tests check constant values. Mitigation: Constants
  remain defined, just not used directly by controllers anymore.
