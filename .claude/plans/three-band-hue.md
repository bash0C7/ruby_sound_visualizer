# Plan: Three-Band Hue System

## Goal

Implement a color system where hue varies based on bass/mid/high energy across a 140-degree range (base color +/- 70 degrees), with 3 preset base color modes.

## Current State

`src/ruby/color_palette.rb` already has:
- `@@hue_mode` (nil, 1, 2, 3) for color mode selection
- Mode 1: Red center (240-120deg, 240deg range)
- Mode 2: Green center (0-240deg, 240deg range)
- Mode 3: Blue center (120-360deg, 240deg range)
- Hue shift is calculated from `mid * 0.5 + high * 1.0` weighted ratio

Keyboard mapping in `src/ruby/main.rb:186-199`:
- Keys 0-3 call `ColorPalette.set_hue_mode()`

## Target Design

### Base Colors (per task spec)
- Mode 1: Vivid Red (0deg / 360deg)
- Mode 2: Shocking Yellow (60deg)
- Mode 3: Turquoise Blue (180deg)

### Three-Band Hue Mapping

For each mode, the 140-degree range (base +/- 70deg) is split into 3 bands:
```
|--- bass (low 1/3) ---|--- mid (middle 1/3) ---|--- high (upper 1/3) ---|
base - 70deg            base                      base + 70deg
```

The actual hue position within this range is determined by relative energy:
- Dominant bass -> hue shifts toward lower end
- Dominant mid -> hue stays near center
- Dominant high -> hue shifts toward upper end

### Calculation

```ruby
# Base hue in degrees
BASE_HUES = { 1 => 0.0, 2 => 60.0, 3 => 180.0 }

# Weighted position within the 140-degree range
total = bass + mid + high
if total > 0.01
  # Map bass->0.0, mid->0.5, high->1.0
  position = (mid * 0.5 + high * 1.0) / total  # 0.0 to 1.0
else
  position = 0.5
end

# Convert to hue offset from base (-70 to +70)
hue_offset = (position - 0.5) * 140.0  # -70 to +70 degrees

# Final hue
base = BASE_HUES[@@hue_mode]
hue = ((base + hue_offset + @@hue_offset) % 360.0) / 360.0
```

## Changes Required

### 1. src/ruby/color_palette.rb

- Add `BASE_HUES` constant
- Change `HUE_RANGE` from 240deg to 140deg
- Rewrite `frequency_to_color` hue calculation
- Rewrite `frequency_to_color_at_distance` to use same base + range

### 2. src/ruby/main.rb

- Update log messages to reflect new color names (Vivid Red, Shocking Yellow, Turquoise Blue)

## TDD Approach

1. Write tests for `ColorPalette.frequency_to_color` with each mode
   - Verify hue stays within base +/- 70deg range
   - Verify bass-dominant input shifts hue down
   - Verify high-dominant input shifts hue up
   - Verify zero-energy returns gray
2. Implement the new calculation
3. Test `frequency_to_color_at_distance` similarly
4. Visual verification with Chrome MCP (local session)

## Estimated Scope

- Files: `src/ruby/color_palette.rb`, `src/ruby/main.rb`
- Risk: Medium (visual output changes, but logic is isolated to ColorPalette)
