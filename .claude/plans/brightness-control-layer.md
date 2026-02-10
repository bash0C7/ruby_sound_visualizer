# Plan: Brightness/Lightness Control Layer

## Goal

Add a dedicated rendering layer that controls brightness/lightness capping, making it possible to exclude MAX values from calculations and prevent configuration oversights.

## Current State

Brightness and lightness are controlled via global variables scattered across files:

- `$max_brightness` (main.rb:10): Caps particle color output in ParticleSystem
- `$max_lightness` (main.rb:11): Caps HSV value in ColorPalette
- Both use URL parameters and keyboard controls (6/7 and 8/9 keys)

### Current cap application points:

1. **ColorPalette** (`color_palette.rb:43-46, 98-101`): `$max_lightness` caps `value` in HSV
2. **ParticleSystem** (`particle_system.rb:89-90`): `$max_brightness` caps final RGB per particle
3. **GeometryMorpher** (`geometry_morpher.rb:42-44`): `emissive_intensity` has hardcoded max of 2.0
4. **BloomController** (`bloom_controller.rb:16-18`): `strength` has hardcoded max of 4.5

### Problems

- Max caps are checked with `defined?()` guard (`if defined?($max_lightness) && ...`)
- Hardcoded limits in GeometryMorpher and BloomController are not configurable
- Easy to forget applying caps when adding new visual elements
- No centralized brightness policy

## Target Design

### BrightnessPolicy module

A centralized module that defines brightness constraints and applies them uniformly:

```ruby
module BrightnessPolicy
  # Configurable caps (writable from keyboard and DevTool)
  @@max_brightness = 255  # RGB cap (0-255 scale)
  @@max_lightness = 255   # HSV value cap (0-255 scale)
  @@max_emissive = 2.0    # Emissive intensity cap
  @@max_bloom = 4.5       # Bloom strength cap
  @@exclude_max = false   # When true, formulas ignore MAX clipping

  def self.cap_rgb(r, g, b)
    return [r, g, b] if @@exclude_max
    max_c = @@max_brightness / 255.0
    [[r, max_c].min, [g, max_c].min, [b, max_c].min]
  end

  def self.cap_value(v)
    return v if @@exclude_max
    [v, @@max_lightness / 255.0].min
  end

  def self.cap_emissive(intensity)
    return intensity if @@exclude_max
    [intensity, @@max_emissive].min
  end

  def self.cap_bloom(strength)
    return strength if @@exclude_max
    [strength, @@max_bloom].min
  end

  # Setters for keyboard/DevTool control
  def self.adjust_brightness(delta); ... end
  def self.adjust_lightness(delta); ... end
  def self.toggle_exclude_max; ... end
end
```

### Integration

Each class calls `BrightnessPolicy` instead of checking globals directly:
- `ColorPalette`: `value = BrightnessPolicy.cap_value(value)`
- `ParticleSystem`: `color = BrightnessPolicy.cap_rgb(*color)`
- `GeometryMorpher`: `intensity = BrightnessPolicy.cap_emissive(intensity)`
- `BloomController`: `strength = BrightnessPolicy.cap_bloom(strength)`

## Changes Required

### 1. New file: `src/ruby/brightness_policy.rb`

- Implement `BrightnessPolicy` module as described above
- Add to `index.html` `<script type="text/ruby" src=...>` list (requires user approval)

### 2. `src/ruby/color_palette.rb`

- Replace `$max_lightness` check with `BrightnessPolicy.cap_value()`

### 3. `src/ruby/particle_system.rb`

- Replace `$max_brightness` check with `BrightnessPolicy.cap_rgb()`

### 4. `src/ruby/geometry_morpher.rb`

- Replace hardcoded `[@emissive_intensity, 2.0].min` with `BrightnessPolicy.cap_emissive()`

### 5. `src/ruby/bloom_controller.rb`

- Replace hardcoded `[@strength, 4.5].min` with `BrightnessPolicy.cap_bloom()`

### 6. `src/ruby/main.rb`

- Remove `$max_brightness` and `$max_lightness` globals
- Register `BrightnessPolicy` keyboard callbacks
- URL parameter parsing delegates to `BrightnessPolicy`

## TDD Approach

1. Write tests for `BrightnessPolicy` module (cap methods, exclude_max toggle)
2. Create `brightness_policy.rb`
3. Refactor each consumer class one at a time with tests
4. Verify keyboard controls still work
5. Visual verification with Chrome MCP (local session)

## Estimated Scope

- Files: New `brightness_policy.rb`, plus 5 existing files modified
- Risk: Medium (touches multiple files, but changes are mechanical replacements)
- Dependency: Consider combining with "config centralization" task
