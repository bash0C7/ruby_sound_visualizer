# Plan: In-Browser Ruby Prompt Area (VJ Mode) - v2

## Status

Revised plan based on current codebase state (2026-02-12).
Previous dependencies (config-centralization, ruby-class-restructure) are resolved:
- VisualizerPolicy module provides centralized config with set_by_key/get_by_key/list_keys/reset_runtime
- Ruby classes are modular with clean interfaces
- devtool callbacks pattern (rubyConfigSet/Get/List/Reset) provides JS-Ruby bridge template

## Goal

Implement an on-screen prompt area where VJs type short Ruby commands to control
visualizations in real-time. Minimal keystrokes, maximum control.

## Architecture

```
User types: "c 1; s 2.0; bm 4.0" + Enter
  |
  v
[Prompt UI] (HTML input, toggle with ` key)  -- JS: minimal
  |
  v  window.rubyExecPrompt(string)
[VJPad#exec]  -- Ruby: DSL evaluation via instance_eval
  |
  v  method dispatch
[VisualizerPolicy / ColorPalette]  -- Ruby: existing modules
  |
  v  values updated
Next animation frame picks up new values
```

## VJ Command API (VJPad DSL)

Design principles:
- No args = getter (show current value)
- With args = setter (change value)
- Single letter or 2-letter commands for speed
- Valid Ruby syntax (commands are method calls evaluated via instance_eval)
- Multiple commands with semicolons: `c 1; s 2.0`

### Command Reference

| Command | Args | Description | Example | Range |
|---------|------|-------------|---------|-------|
| `c` | mode | Color mode | `c 1`, `c :red` | 0-3, :gray/:red/:yellow/:blue |
| `h` | degrees | Hue offset (absolute) | `h 45` | 0-360 |
| `s` | value | Sensitivity | `s 1.5` | 0.05-10.0 |
| `br` | value | Max brightness | `br 200` | 0-255 |
| `lt` | value | Max lightness | `lt 200` | 0-255 |
| `em` | value | Max emissive | `em 1.5` | 0.0-10.0 |
| `bm` | value | Max bloom | `bm 3.0` | 0.0-10.0 |
| `x` | - | Toggle exclude_max | `x` | bool |
| `r` | - | Reset all to defaults | `r` | - |
| `i` | - | Show all current values | `i` | - |
| `burst` | force | Trigger particle explosion | `burst`, `burst 2.0` | 0.0-3.0 |
| `flash` | intensity | Bloom spike | `flash`, `flash 2.0` | 0.0-3.0 |

### Symbol aliases for color modes

```ruby
c :red      # same as c 1
c :yellow   # same as c 2
c :blue     # same as c 3
c :gray     # same as c 0
# Short aliases
c :r        # same as c 1
c :y        # same as c 2
c :b        # same as c 3
c :g        # same as c 0
```

### Getter mode (no args)

```ruby
c           # => "color: red"
h           # => "hue: 45.0"
s           # => "sens: 1.5"
br          # => "bright: 200"
i           # => "c:red h:45.0 | s:1.5 br:200 lt:255 | em:2.0 bm:4.5 x:false"
```

## File Changes

### New Files

1. **`src/ruby/vj_pad.rb`** - VJ prompt DSL context and command executor
2. **`test/test_vj_pad.rb`** - Comprehensive unit tests

### Modified Files

3. **`src/ruby/color_palette.rb`** - Add `set_hue_offset(val)` class method (absolute setter)
4. **`test/test_color_palette.rb`** - Test for new set_hue_offset method
5. **`src/ruby/main.rb`** - Initialize VJPad, register `rubyExecPrompt` callback
6. **`test/test_helper.rb`** - Add require for vj_pad
7. **`index.html`** - Add prompt UI overlay (HTML/CSS/JS) -- REQUIRES USER APPROVAL

## VJPad Class Design

```ruby
class VJPad
  attr_reader :history, :last_result

  COLOR_ALIASES = {
    red: 1, r: 1,
    yellow: 2, y: 2,
    blue: 3, b: 3,
    gray: 0, g: 0
  }.freeze

  COLOR_NAMES = { 0 => 'gray', 1 => 'red', 2 => 'yellow', 3 => 'blue' }.freeze

  def initialize
    @history = []
    @last_result = nil
  end

  def exec(input)
    input = input.to_s.strip
    return { ok: true, msg: '' } if input.empty?
    @history << input
    result = instance_eval(input)
    @last_result = result.to_s
    { ok: true, msg: @last_result }
  rescue => e
    @last_result = e.message
    { ok: false, msg: e.message }
  end

  # --- DSL Commands ---

  def c(mode = :_get)
    if mode == :_get
      name = COLOR_NAMES[ColorPalette.get_hue_mode] || 'gray'
      return "color: #{name}"
    end
    resolved = mode.is_a?(Symbol) ? (COLOR_ALIASES[mode] || 0) : mode.to_i
    actual_mode = resolved == 0 ? nil : resolved
    ColorPalette.set_hue_mode(actual_mode)
    "color: #{COLOR_NAMES[resolved] || 'gray'}"
  end

  def h(deg = :_get)
    if deg == :_get
      return "hue: #{ColorPalette.get_hue_offset.round(1)}"
    end
    ColorPalette.set_hue_offset(deg.to_f)
    "hue: #{ColorPalette.get_hue_offset.round(1)}"
  end

  def s(val = :_get)
    return "sens: #{VisualizerPolicy.sensitivity}" if val == :_get
    VisualizerPolicy.sensitivity = val.to_f
    "sens: #{VisualizerPolicy.sensitivity}"
  end

  def br(val = :_get)
    return "bright: #{VisualizerPolicy.max_brightness}" if val == :_get
    VisualizerPolicy.max_brightness = val.to_i
    "bright: #{VisualizerPolicy.max_brightness}"
  end

  def lt(val = :_get)
    return "light: #{VisualizerPolicy.max_lightness}" if val == :_get
    VisualizerPolicy.max_lightness = val.to_i
    "light: #{VisualizerPolicy.max_lightness}"
  end

  def em(val = :_get)
    return "emissive: #{VisualizerPolicy.max_emissive}" if val == :_get
    VisualizerPolicy.max_emissive = val.to_f
    "emissive: #{VisualizerPolicy.max_emissive}"
  end

  def bm(val = :_get)
    return "bloom: #{VisualizerPolicy.max_bloom}" if val == :_get
    VisualizerPolicy.max_bloom = val.to_f
    "bloom: #{VisualizerPolicy.max_bloom}"
  end

  def x
    VisualizerPolicy.exclude_max = !VisualizerPolicy.exclude_max
    "exclude_max: #{VisualizerPolicy.exclude_max}"
  end

  def r
    VisualizerPolicy.reset_runtime
    ColorPalette.set_hue_mode(nil)
    "reset done"
  end

  def i
    cn = COLOR_NAMES[ColorPalette.get_hue_mode] || 'gray'
    ho = ColorPalette.get_hue_offset.round(1)
    se = VisualizerPolicy.sensitivity
    b = VisualizerPolicy.max_brightness
    l = VisualizerPolicy.max_lightness
    e = VisualizerPolicy.max_emissive
    bl = VisualizerPolicy.max_bloom
    ex = VisualizerPolicy.exclude_max
    "c:#{cn} h:#{ho} | s:#{se} br:#{b} lt:#{l} | em:#{e} bm:#{bl} x:#{ex}"
  end
end
```

## ColorPalette Change

Add absolute hue offset setter:

```ruby
# In ColorPalette class
def hue_offset=(val)
  @hue_offset = val.to_f % 360.0
end

# Class-level
def self.set_hue_offset(val)
  shared.hue_offset = val
end
```

## main.rb Integration

```ruby
$vj_pad = VJPad.new

JS.global[:rubyExecPrompt] = lambda do |input|
  begin
    result = $vj_pad.exec(input.to_s)
    # Return result as JS-readable string
    if result[:ok]
      result[:msg]
    else
      "ERR: #{result[:msg]}"
    end
  rescue => e
    "ERR: #{e.message}"
  end
end
```

## Prompt UI (index.html) - Minimal JS

Toggle: backtick (`) key
Layout: Single-line input at bottom, above status bar

```
+--------------------------------------------------+
|                                                    |
|              [3D Visualization Area]               |
|                                                    |
+--------------------------------------------------+
| > c 1; s 2.0_                        => color: red|  <- Prompt (toggled)
+--------------------------------------------------+
| FPS: XX | sens:1.0 br:255 lt:255                  |  <- Existing status
+--------------------------------------------------+
```

JS responsibilities (minimal):
- Show/hide prompt input on backtick key
- Capture Enter key → call window.rubyExecPrompt(value)
- Display result string
- Up/Down arrow for history (maintained in JS array for responsiveness)
- Prevent keyboard events from propagating to Ruby handler when prompt is open

## TDD Implementation Order

### Step 1: ColorPalette#set_hue_offset (Red)
- Test: `test_set_hue_offset_absolute` - set to 45, verify 45
- Test: `test_set_hue_offset_wraps_360` - set to 400, verify 40
- Test: `test_set_hue_offset_negative` - set to -10, verify 350
- Implement: Add `hue_offset=` and `self.set_hue_offset`

### Step 2: VJPad getter commands (Red → Green)
- Test each getter: `c`, `h`, `s`, `br`, `lt`, `em`, `bm`, `i`
- Test default values after reset
- Implement getter DSL methods

### Step 3: VJPad setter commands (Red → Green)
- Test each setter: `c 1`, `h 45`, `s 1.5`, `br 200`, `lt 200`, `em 1.5`, `bm 3.0`
- Test symbol aliases: `c :red`, `c :r`
- Test range clamping (via VisualizerPolicy)
- Implement setter DSL methods

### Step 4: VJPad exec and error handling (Red → Green)
- Test: `exec("c 1")` returns `{ ok: true, msg: "color: red" }`
- Test: `exec("invalid_method")` returns `{ ok: false, msg: ... }`
- Test: `exec("c 1; s 2.0")` executes both (semicolons)
- Test: `exec("")` handles empty input
- Test: history tracking
- Implement exec method

### Step 5: VJPad toggle and reset (Red → Green)
- Test: `x` toggles exclude_max
- Test: `r` resets all to defaults
- Implement toggle and reset

### Step 6: main.rb integration
- Register rubyExecPrompt callback
- Initialize $vj_pad

### Step 7: index.html prompt UI
- REQUIRES USER APPROVAL
- HTML/CSS for prompt overlay
- JS for toggle, input, result display, history

## Risks

- `instance_eval` on user input: Necessary for DSL, but arbitrary Ruby execution possible.
  In this context (local VJ tool, no server), this is acceptable.
- Single-letter method names (`c`, `h`, `s`, etc.) might conflict with Ruby builtins.
  Verified: `c`, `h`, `s`, `br`, `lt`, `em`, `bm`, `x`, `r`, `i` do not conflict with
  Object instance methods in Ruby 3.4.

## Questions for User (Decision Points)

1. **index.html modification**: Required for prompt UI. OK to proceed?
2. **Toggle key**: Backtick (`) is game console standard. Alternative: Tab? Other preference?
3. **Additional commands**: Beyond parameter control - should we add action triggers?
   e.g., `burst` (particle explosion), `cam` (camera reset), `flash` (bloom spike)
4. **Sequence/preset support**: Include in Phase 1 or defer to separate task?
