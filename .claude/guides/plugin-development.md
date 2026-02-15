# VJ Pad Plugin Development Guide

How to add and maintain VJ Pad plugins in the current architecture.

## Architecture Overview

```text
src/ruby/plugins/vj_<name>.rb
  -> VJPlugin.define(:name)
  -> VJPlugin registry
  -> VJPad method_missing dispatch
  -> pending_actions queue
  -> EffectDispatcher.dispatch(effects)
  -> EffectManager / VisualizerPolicy updates
  -> JSBridge -> Three.js output
```

Key runtime flow:
1. User executes command from control panel VJ Pad input.
2. `VJPad#exec` evaluates DSL expression.
3. Plugin command pushes an action into `pending_actions`.
4. Main loop consumes actions and dispatches effects.

## Quick Start

### 1. Create a plugin file

Create `src/ruby/plugins/vj_nova.rb`:

```ruby
VJPlugin.define(:nova) do
  desc "Combined impulse and bloom burst"
  param :force, default: 1.0, range: 0.0..3.0
  param :glow, default: 1.5, range: 0.0..5.0

  on_trigger do |params|
    f = params[:force]
    g = params[:glow]
    {
      impulse: { bass: f, mid: f, high: f, overall: f },
      bloom_flash: g
    }
  end
end
```

### 2. Register in `index.html`

Add a Ruby script tag in the plugin section:

```html
<script type="text/ruby" src="src/ruby/plugins/vj_nova.rb"></script>
```

### 3. Ensure test loading includes the plugin

In test setup (usually `test/test_helper.rb`), require the plugin so tests see it.

### 4. Use it

Open control panel with `p`, then run VJ Pad commands like:

```text
nova
nova 2.0 3.5
```

## Plugin Definition DSL

### `VJPlugin.define(name) { ... }`

Registers a plugin under `name`.

### `desc(text)`

Human-readable description shown by `plugins` command output.

### `param(name, default:, range: nil)`

Declares positional arguments.

Behavior:
- inputs are converted to `Float`
- default is used when omitted
- optional range clamps values

### `on_trigger { |params| ... }`

Called with resolved parameters and returns an effect hash.

## Effect Hash Reference

`EffectDispatcher` currently handles three keys.

### `impulse:`

```ruby
{
  impulse: {
    bass: 1.0,
    mid: 0.6,
    high: 0.4,
    overall: 1.0
  }
}
```

Mapped into `EffectManager#inject_impulse`.

### `bloom_flash:`

```ruby
{ bloom_flash: 2.0 }
```

Mapped into `EffectManager#inject_bloom_flash`.

### `set_param:`

```ruby
{
  set_param: {
    "bloom_base_strength" => 2.5,
    "particle_explosion_base_prob" => 0.35
  }
}
```

Mapped via `VisualizerPolicy.set_by_key`.

### Combining effects

```ruby
on_trigger do |params|
  l = params[:level]
  {
    impulse: { bass: l, mid: l, high: l, overall: l },
    bloom_flash: l * 1.2,
    set_param: { "bloom_base_strength" => 1.5 + l }
  }
end
```

## Writing Tests

Use TDD style for plugin behavior.

### Test structure

Create `test/test_vj_nova.rb` and validate:
- registration
- default parameter behavior
- range clamp behavior
- `VJPad#exec` behavior and queued actions

### Example

```ruby
require_relative 'test_helper'

class TestVJNova < Test::Unit::TestCase
  def setup
    VJPlugin.reset!
    load File.expand_path('../src/ruby/plugins/vj_nova.rb', __dir__)
  end

  def test_plugin_registered
    assert VJPlugin.find(:nova)
  end

  def test_exec_queues_action
    pad = VJPad.new
    result = pad.exec('nova 2.0 3.0')
    assert result[:ok]
    assert_equal :nova, pad.pending_actions[0][:name]
  end
end
```

### Running tests

```bash
bundle exec rake test
```

Or run a single file:

```bash
ruby -Itest test/test_vj_nova.rb
```

## Plugin Examples

### Impulse-only plugin

```ruby
VJPlugin.define(:kick) do
  desc "Bass-focused kick"
  param :force, default: 1.2, range: 0.0..5.0

  on_trigger do |params|
    f = params[:force]
    { impulse: { bass: f, overall: f * 0.8 } }
  end
end
```

### Preset-style plugin

```ruby
VJPlugin.define(:boost) do
  desc "Temporary aggressive preset"
  param :level, default: 1.0, range: 0.0..3.0

  on_trigger do |params|
    l = params[:level]
    {
      bloom_flash: l,
      set_param: {
        "bloom_energy_scale" => 2.5 + l,
        "particle_explosion_force_scale" => 0.55 + l * 0.2
      }
    }
  end
end
```

## VJPlugin Module API

### Registry methods

- `VJPlugin.find(:name)`
- `VJPlugin.all`
- `VJPlugin.names`
- `VJPlugin.reset!`

### `PluginDefinition` methods

- `name`
- `description`
- `params`
- `resolve_params(args)`
- `execute(args)`
- `format_result(resolved)`

`format_result` behavior:
- empty resolved hash -> `<name>!`
- non-empty resolved hash -> `<name>: value1, value2, ...`

## File Naming Convention

| File | Location | Purpose |
|---|---|---|
| Plugin source | `src/ruby/plugins/vj_<name>.rb` | Plugin definition |
| Plugin tests | `test/test_vj_<name>.rb` | Unit tests |
| Browser load point | `index.html` | Runtime script loading |
| Test load point | `test/test_helper.rb` | Test environment requires |

## Non-Effect Plugins

Some commands are plugin-registered for discovery but implemented mainly through dedicated VJPad methods.

### Serial plugin (`vj_serial.rb`)

Available commands:

```text
sc              # connect serial
sd              # disconnect serial
ss "text"       # send text
sr [n]          # show RX log (last n lines)
st [n]          # show TX log (last n lines)
sb [baud]       # get/set baud rate
si              # serial info/status
sa [1/0]        # auto-send audio frames on/off
scl [all/rx/tx] # clear logs
```

### Serial audio commands (built-in VJPad, not plugin-dispatched)

```text
sao [1/0]       # serial audio on/off (PWM oscillator)
sav [0-100]     # serial audio volume (percentage)
sai             # serial audio info/status
sad             # open audio output device picker
```

These control `SerialAudioSource` which generates PWM audio from serial frequency data.

### WordArt plugin (`vj_wordart.rb`)

```text
wa "HELLO"
was
```

### Pen command (built-in VJPad command, not plugin-dispatched)

```text
pc
```

## Debugging Tips

- Run `plugins` in VJ Pad to confirm registration.
- Inspect `pad.pending_actions` in unit tests.
- Verify dispatch behavior through `EffectDispatcher` tests.
- Use browser console logs (`[Ruby] ...`) for runtime traces.
- Keep plugin side effects minimal and encode behavior through explicit effect hashes.
