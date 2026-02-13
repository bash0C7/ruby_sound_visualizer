---
name: create-plugin
description: Scaffold a new VJ Pad plugin with source file, test file, and registration
disable-model-invocation: false
---

# Create VJ Pad Plugin

Scaffold a new VJ Pad plugin command. This skill creates the plugin source file, test file, and updates registration points.

## Procedure

### 1. Gather Requirements

Ask the user for:
- Plugin name (symbol, e.g., `shockwave`)
- Description (one line)
- Parameters (name, default, optional range)
- Desired visual effects (impulse bands, bloom flash, or combination)

### 2. Create Plugin Source File

Create `src/ruby/plugins/vj_<name>.rb`:

```ruby
# Plugin: <name>
# <description>
VJPlugin.define(:<name>) do
  desc "<description>"
  param :<param1>, default: <default>, range: <min>..<max>

  on_trigger do |params|
    # Return effect hash
    {
      impulse: { bass: ..., mid: ..., high: ..., overall: ... },
      bloom_flash: ...
    }
  end
end
```

### 3. Create Test File (TDD - Write Test First)

Create `test/test_vj_<name>.rb`:

```ruby
require_relative 'test_helper'

class TestVJ<Name>Plugin < Test::Unit::TestCase
  def setup
    VJPlugin.reset!
    load File.expand_path('../src/ruby/plugins/vj_<name>.rb', __dir__)
  end

  def test_plugin_registered
    assert VJPlugin.find(:<name>)
  end

  def test_description
    plugin = VJPlugin.find(:<name>)
    assert_equal "<description>", plugin.description
  end

  def test_default_effects
    plugin = VJPlugin.find(:<name>)
    result = plugin.execute({})
    # Assert expected effect values with defaults
  end

  def test_custom_parameters
    plugin = VJPlugin.find(:<name>)
    result = plugin.execute({ <param>: <value> })
    # Assert expected effect values with custom params
  end

  def test_range_clamping
    plugin = VJPlugin.find(:<name>)
    # Test that values outside range are clamped
    result = plugin.execute({ <param>: <over_max> })
    # Assert clamped value
  end

  def test_via_vj_pad
    pad = VJPad.new
    result = pad.exec("<name>")
    assert_equal true, result[:ok]
    assert_equal "<name>!", result[:msg]
    assert_equal 1, pad.pending_actions.length
    assert_equal :<name>, pad.pending_actions[0][:name]
  end

  def test_via_vj_pad_with_arg
    pad = VJPad.new
    result = pad.exec("<name> 2.0")
    assert_equal true, result[:ok]
    assert_equal "<name>: 2.0", result[:msg]
  end
end
```

### 4. Register Plugin in index.html

Add a script tag in the VJ Pad Plugins section of `index.html`:

```html
<!-- VJ Pad Plugins (src/ruby/plugins/vj_*.rb) -->
<script type="text/ruby" src="src/ruby/plugins/vj_burst.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_flash.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_<name>.rb"></script>
```

### 5. Register in test_helper.rb

Add require at the end of the plugins section in `test/test_helper.rb`:

```ruby
# Load plugins (same order as index.html)
require_relative '../src/ruby/plugins/vj_burst'
require_relative '../src/ruby/plugins/vj_flash'
require_relative '../src/ruby/plugins/vj_<name>'
```

### 6. Run Tests

```bash
# Run plugin test only
BUNDLE_GEMFILE="" ruby -Itest test/test_vj_<name>.rb

# Run all tests to verify no regressions
BUNDLE_GEMFILE="" ruby -Itest -e "Dir.glob('test/test_*.rb').each { |f| require_relative f }"
```

### 7. Verify All Tests Pass

Ensure 100% pass rate. Fix any failures before proceeding.

## Available Effect Types

Plugins return a Hash with these optional keys:

| Key | Type | Effect | Range |
|-----|------|--------|-------|
| `impulse.bass` | Float | Low frequency particle explosion, X-axis rotation | 0.0-5.0 |
| `impulse.mid` | Float | Mid frequency particle spread, Y-axis rotation | 0.0-5.0 |
| `impulse.high` | Float | High frequency color brightness, Z-axis rotation | 0.0-5.0 |
| `impulse.overall` | Float | Combined intensity, geometry scale, camera shake | 0.0-5.0 |
| `bloom_flash` | Float | Bloom glow flash intensity | 0.0-5.0 |

## Plugin Examples

### Impulse-Only Plugin

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

### Bloom-Only Plugin

```ruby
VJPlugin.define(:glow) do
  desc "Soft bloom glow"
  param :intensity, default: 1.0, range: 0.0..3.0
  on_trigger do |params|
    { bloom_flash: params[:intensity] }
  end
end
```

### Multi-Parameter Plugin

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

## Reference

- Plugin Development Guide: `.claude/guides/plugin-development.md`
- VJPlugin source: `src/ruby/vj_plugin.rb`
- EffectDispatcher source: `src/ruby/effect_dispatcher.rb`
- Existing plugins: `src/ruby/plugins/vj_*.rb`
