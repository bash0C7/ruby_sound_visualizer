# VJ Pad Plugin Development Guide

This guide covers how to create custom VJ Pad plugins for the Ruby WASM Sound Visualizer. Plugins add new commands to the VJ Pad prompt, each triggering visual effects when executed.

## Architecture Overview

```
Plugin File (src/ruby/plugins/vj_<name>.rb)
  ↓ VJPlugin.define(:name) { ... }
VJPlugin Registry
  ↓ method_missing lookup
VJPad DSL (user types command)
  ↓ pending_actions queue
EffectDispatcher
  ↓ dispatch(effects)
EffectManager → ParticleSystem / BloomController / ...
  ↓
JSBridge → Three.js rendering
```

## Quick Start

### 1. Create a Plugin File

Create `src/ruby/plugins/vj_<name>.rb`:

```ruby
VJPlugin.define(:shockwave) do
  desc "Trigger a shockwave with impulse and bloom"
  param :force, default: 1.0, range: 0.0..5.0

  on_trigger do |params|
    f = params[:force]
    {
      impulse: { bass: f, mid: f * 0.5, high: f * 0.3, overall: f },
      bloom_flash: f * 0.8
    }
  end
end
```

### 2. Register in index.html

Add a script tag after the existing plugin entries:

```html
<!-- VJ Pad Plugins (src/ruby/plugins/vj_*.rb) -->
<script type="text/ruby" src="src/ruby/plugins/vj_burst.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_flash.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_shockwave.rb"></script>
```

### 3. Add to Test Helper

In `test/test_helper.rb`, add a require for testing:

```ruby
# Load plugins (same order as index.html)
require_relative '../src/ruby/plugins/vj_burst'
require_relative '../src/ruby/plugins/vj_flash'
require_relative '../src/ruby/plugins/vj_shockwave'
```

### 4. Use It

Open VJ Pad (backtick key) and type:

```
shockwave       # default force 1.0
shockwave 2.5   # custom force
```

## Plugin Definition DSL

### `VJPlugin.define(name, &block)`

Registers a new plugin command. The block is evaluated in the context of a `PluginDefinition` instance.

```ruby
VJPlugin.define(:my_effect) do
  # DSL methods available inside this block:
  desc "..."
  param :name, default: value, range: min..max
  on_trigger do |params|
    { ... }  # effect hash
  end
end
```

### `desc(text)`

Sets a human-readable description for the plugin. Used in documentation and the `plugins` command.

```ruby
desc "Inject impulse across all frequency bands"
```

### `param(name, default:, range: nil)`

Declares a parameter that the user can pass as an argument. Parameters are positional (first param gets first argument, second param gets second, etc.).

- `name` - Symbol identifying the parameter
- `default:` - Default value when the user omits the argument
- `range:` - Optional Range for clamping (e.g., `0.0..5.0`)

All parameter values are converted to Float automatically.

```ruby
param :force, default: 1.0
param :intensity, default: 0.5, range: 0.0..3.0
param :spread, default: 1.0, range: 0.1..10.0
```

### `on_trigger { |params| ... }`

Defines the effect logic. Receives a Hash of resolved parameter values (defaults applied, ranges clamped). Must return an effect hash.

```ruby
on_trigger do |params|
  f = params[:force]
  { impulse: { bass: f, overall: f } }
end
```

## Effect Hash Reference

The `on_trigger` block returns a Hash describing what visual effects to apply. Available keys:

### `impulse:`

Injects energy impulse into the effect system. Affects particle explosions, geometry scaling, and camera shake.

```ruby
{
  impulse: {
    bass: 1.0,      # Low frequency impulse (0.0-5.0)
    mid: 0.5,       # Mid frequency impulse (0.0-5.0)
    high: 0.3,      # High frequency impulse (0.0-5.0)
    overall: 1.0    # Overall energy impulse (0.0-5.0)
  }
}
```

All keys are optional. Omitted keys default to 0.0.

Visual mapping:
- `bass` - Particle explosion force, X-axis rotation, camera shake
- `mid` - Particle spread, Y-axis rotation
- `high` - Particle color brightness, Z-axis rotation
- `overall` - Combined effect intensity, geometry scale

### `bloom_flash:`

Triggers a bloom (glow) flash effect. The value controls peak brightness.

```ruby
{ bloom_flash: 2.0 }  # Intensity (0.0-5.0)
```

### Combining Effects

Multiple effect types can be combined in a single hash:

```ruby
on_trigger do |params|
  f = params[:force]
  {
    impulse: { bass: f, mid: f, high: f, overall: f },
    bloom_flash: f * 0.5
  }
end
```

## Writing Tests

Plugin tests verify the effect hash output. Use TDD (write test first).

### Test File Structure

Create `test/test_vj_<name>.rb`:

```ruby
require_relative 'test_helper'

class TestVJShockwavePlugin < Test::Unit::TestCase
  def setup
    VJPlugin.reset!
    # Re-register (reset clears registry)
    load File.expand_path('../src/ruby/plugins/vj_shockwave.rb', __dir__)
  end

  def test_plugin_registered
    assert VJPlugin.find(:shockwave)
  end

  def test_default_effects
    plugin = VJPlugin.find(:shockwave)
    result = plugin.execute({})
    assert_in_delta 1.0, result[:impulse][:bass], 0.001
    assert_in_delta 0.8, result[:bloom_flash], 0.001
  end

  def test_custom_force
    plugin = VJPlugin.find(:shockwave)
    result = plugin.execute({ force: 2.0 })
    assert_in_delta 2.0, result[:impulse][:bass], 0.001
  end

  def test_range_clamping
    plugin = VJPlugin.find(:shockwave)
    result = plugin.execute({ force: 10.0 })
    assert_in_delta 5.0, result[:impulse][:bass], 0.001
  end

  def test_via_vj_pad
    pad = VJPad.new
    result = pad.exec("shockwave 2.0")
    assert_equal true, result[:ok]
    assert_equal "shockwave: 2.0", result[:msg]
    actions = pad.pending_actions
    assert_equal :shockwave, actions[0][:name]
  end
end
```

### Running Tests

```bash
# Single plugin test
BUNDLE_GEMFILE="" ruby -Itest test/test_vj_shockwave.rb

# All tests
BUNDLE_GEMFILE="" ruby -Itest -e "Dir.glob('test/test_*.rb').each { |f| require_relative f }"
```

## Plugin Examples

### Bass-Only Burst

```ruby
VJPlugin.define(:bass_hit) do
  desc "Bass-focused impulse"
  param :force, default: 1.5, range: 0.0..5.0

  on_trigger do |params|
    f = params[:force]
    { impulse: { bass: f, overall: f * 0.3 } }
  end
end
```

### Multi-Parameter Effect

```ruby
VJPlugin.define(:nova) do
  desc "Combined impulse and bloom nova"
  param :force, default: 1.0, range: 0.0..3.0
  param :glow, default: 2.0, range: 0.0..5.0

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

Usage: `nova 2.0 3.0` (force=2.0, glow=3.0)

## VJPlugin Module API

### Registry Methods

```ruby
VJPlugin.find(:name)     # Returns PluginDefinition or nil
VJPlugin.all             # Returns Array of all PluginDefinition instances
VJPlugin.names           # Returns Array of registered Symbol names
VJPlugin.reset!          # Clears all registrations (used in tests)
```

### PluginDefinition Methods

```ruby
plugin = VJPlugin.find(:burst)
plugin.name              # => :burst
plugin.description       # => "Inject impulse across all frequency bands"
plugin.params            # => { force: { default: 1.0, range: nil } }
plugin.execute({})       # => { impulse: { ... } }
plugin.format_result([]) # => "burst!"
plugin.format_result([2.0]) # => "burst: 2.0"
```

## File Naming Convention

| File | Location | Purpose |
|------|----------|---------|
| Plugin source | `src/ruby/plugins/vj_<name>.rb` | Plugin definition |
| Plugin test | `test/test_vj_<name>.rb` | Unit tests |
| Script tag | `index.html` | Browser loading |
| Test require | `test/test_helper.rb` | Test loading |

## Debugging Tips

- Use `JSBridge.log("message")` inside `on_trigger` for console output
- Check browser DevTools console for `[Ruby]` prefixed messages
- Test plugin execution in isolation: `plugin.execute({ force: 2.0 })`
- Use VJ Pad `i` command to check current visualizer state after triggering effects
