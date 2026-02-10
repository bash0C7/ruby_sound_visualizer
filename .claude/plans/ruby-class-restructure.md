# Plan: Restructure Ruby Classes for Locality of Change

## Goal

Reorganize Ruby classes to have clear responsibilities, reduce coupling, and ensure changes to one area don't ripple through the entire codebase.

## Current State Analysis

### Class Dependency Graph

```
main.rb (orchestrator + global state + keyboard handlers + debug formatting)
  ├── AudioAnalyzer (audio analysis + beat detection + smoothing + impulse)
  │     └── FrequencyMapper (band splitting)
  ├── EffectManager (coordinator)
  │     ├── ParticleSystem (particle physics + color via ColorPalette)
  │     ├── GeometryMorpher (torus transform + color via ColorPalette)
  │     ├── BloomController (bloom params)
  │     └── CameraController (camera position)
  ├── VRMDancer (VRM bone animation)
  ├── VRMMaterialController (VRM emissive)
  ├── ColorPalette (color calculation, class methods with @@state)
  ├── JSBridge (Ruby->JS communication)
  └── MathHelper (utility)
```

### Issues

1. **main.rb is a God Object**: Handles initialization, keyboard input, debug formatting, BPM calculation, VRM debug - 257 lines mixing concerns
2. **ColorPalette uses class variables**: `@@hue_mode`, `@@hue_offset`, `@@last_hsv` are global mutable state accessed by multiple classes
3. **Global variables**: `$sensitivity`, `$max_brightness`, `$max_lightness`, `$frame_count`, `$beat_times`, `$estimated_bpm`
4. **EffectManager is thin**: Just delegates to sub-controllers, could do more coordination
5. **Duplicated impulse tracking**: Both `AudioAnalyzer` and `EffectManager` track impulse values

## Target Architecture

### Phase 1: Extract concerns from main.rb

```
main.rb (thin orchestrator only)
  ├── KeyboardHandler (keyboard input dispatch)
  ├── DebugFormatter (debug text formatting)
  ├── BPMEstimator (BPM calculation from beat history)
  └── (existing classes unchanged)
```

### Phase 2: Fix ColorPalette state management

```
# Before: ColorPalette with class variables (global state)
ColorPalette.set_hue_mode(1)
color = ColorPalette.frequency_to_color(analysis)

# After: ColorPalette as instance (owned by EffectManager)
@palette = ColorPalette.new
@palette.hue_mode = 1
color = @palette.frequency_to_color(analysis)
```

### Phase 3: Consolidate impulse tracking

- Remove impulse from `EffectManager` (currently duplicates AudioAnalyzer)
- `AudioAnalyzer#analyze` returns impulse data
- `EffectManager` passes impulse through from analysis result

### Phase 4: Eliminate global variables

- All globals move to `Config` module (see config-centralization plan)
- `$frame_count` moves to main loop state
- `$beat_times` and `$estimated_bpm` move to `BPMEstimator`

## New File Structure

```
src/ruby/
  config.rb              # (from config-centralization task)
  math_helper.rb         # Unchanged
  js_bridge.rb           # Unchanged
  frequency_mapper.rb    # Unchanged
  audio_analyzer.rb      # Remove duplicated impulse (Phase 3)
  color_palette.rb       # Convert to instance-based (Phase 2)
  particle_system.rb     # Unchanged (receives palette instance)
  geometry_morpher.rb    # Unchanged (receives palette instance)
  bloom_controller.rb    # Unchanged
  camera_controller.rb   # Unchanged
  effect_manager.rb      # Owns ColorPalette instance, passes to sub-controllers
  vrm_dancer.rb          # Unchanged
  vrm_material_controller.rb  # Unchanged
  keyboard_handler.rb    # NEW: extracted from main.rb (Phase 1)
  debug_formatter.rb     # NEW: extracted from main.rb (Phase 1)
  bpm_estimator.rb       # NEW: extracted from main.rb (Phase 1)
  main.rb                # Thin orchestrator
```

## Changes Required (by phase)

### Phase 1: Extract from main.rb
- New `src/ruby/keyboard_handler.rb`: Move rubySetColorMode, rubyAdjustSensitivity, rubyShiftHue, rubyAdjustMaxBrightness, rubyAdjustMaxLightness
- New `src/ruby/debug_formatter.rb`: Move debug_text, param_text, key_guide formatting
- New `src/ruby/bpm_estimator.rb`: Move beat_times tracking and BPM calculation
- Simplify `main.rb` to initialization + callback registration only
- Add new files to `index.html` (requires user approval)

### Phase 2: ColorPalette instance
- Convert `@@` variables to `@` instance variables
- EffectManager creates and owns ColorPalette instance
- Pass palette to ParticleSystem and GeometryMorpher via update()
- KeyboardHandler receives palette reference for mode changes

### Phase 3: Impulse consolidation
- Remove impulse tracking from EffectManager
- EffectManager passes impulse from AudioAnalyzer result

### Phase 4: Global elimination
- Depends on config-centralization task

## TDD Approach

Each phase has its own test cycle:
1. Write tests for extracted class (e.g., KeyboardHandler dispatches correctly)
2. Extract the code
3. Verify existing integration tests still pass
4. Repeat for next phase

## Estimated Scope

- Files: 3 new files, 4-6 modified files per phase
- Risk: High (structural changes, multiple classes affected)
- Recommendation: Execute one phase per session, verify after each
