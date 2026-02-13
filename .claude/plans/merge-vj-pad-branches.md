# Plan: Merge VJ Pad Branches and Enhance

## Current State (Post-Merge)

Both branches have been merged via fast-forward into `claude/merge-vj-pad-branches-evSTE`. All 371 tests pass.

### What Already Exists

| Requirement | Status | Implementation |
|---|---|---|
| Plugin system for VJ Pad commands | Done | VJPlugin DSL, EffectDispatcher, method_missing |
| Script tag naming convention (vj_*.rb) | Done | src/ruby/plugins/vj_burst.rb, vj_flash.rb |
| Core API/DSL for plugins | Done | VJPlugin.define, desc, param, on_trigger |
| Existing commands as plugins | Done | burst, flash extracted to plugins |
| Audio control sliders with preview | Done | Control panel UI with 15 sliders |
| Preview without VRM mode | Done | Preview starts before VRM choice |
| All mutable params have sliders | Done | 15 params across 5 groups |

### Gaps to Fill

1. **No `plugins` VJPad command** - users cannot discover available plugins from the prompt
2. **Only 2 plugins** (burst, flash) - need more effect variety for VJ workflow
3. **No dedicated plugin for combined effects** - common VJ operations need shortcuts
4. **Plugin API lacks `set_param` effect** - plugins cannot adjust VisualizerPolicy params
5. **Tasks.md not updated** to reflect completion

## Implementation Plan

### Phase 1: Plugin Discoverability (VJPad `plugins` command)

**TDD: Red -> Green -> Refactor**

1. Write test: `test_plugins_command_lists_registered_plugins` in test_vj_pad.rb
2. Implement `plugins` method in VJPad that returns formatted plugin list
3. Verify test passes

### Phase 2: Add `set_param` Effect Type to EffectDispatcher

Allow plugins to adjust VisualizerPolicy parameters as a side effect. This makes it possible for plugins to create complex preset effects (e.g., a "rave" plugin that cranks up bloom + particle prob).

**TDD: Red -> Green -> Refactor**

1. Write test in test_effect_dispatcher.rb: `test_dispatch_set_param_adjusts_policy`
2. Implement `dispatch_set_param` in EffectDispatcher
3. Effect hash format: `{ set_param: { "bloom_base_strength" => 3.0, "particle_friction" => 0.92 } }`

### Phase 3: New Plugins

Add 3 practical VJ plugins:

#### 3a. `shockwave` - Combined bass impulse + bloom flash

```ruby
VJPlugin.define(:shockwave) do
  desc "Bass-heavy impulse with bloom flash"
  param :force, default: 1.5, range: 0.0..5.0
  on_trigger do |params|
    f = params[:force]
    {
      impulse: { bass: f, mid: f * 0.5, high: f * 0.3, overall: f },
      bloom_flash: f * 0.8
    }
  end
end
```

#### 3b. `strobe` - Bloom-only quick flash

```ruby
VJPlugin.define(:strobe) do
  desc "Quick bloom strobe flash"
  param :intensity, default: 3.0, range: 0.0..5.0
  on_trigger do |params|
    { bloom_flash: params[:intensity] }
  end
end
```

#### 3c. `rave` - Preset that cranks visual parameters + triggers effect

```ruby
VJPlugin.define(:rave) do
  desc "Max energy preset with impulse + param boost"
  param :level, default: 1.0, range: 0.0..3.0
  on_trigger do |params|
    l = params[:level]
    {
      impulse: { bass: l, mid: l, high: l, overall: l },
      bloom_flash: l * 2.0,
      set_param: {
        "bloom_base_strength" => 2.0 + l,
        "particle_explosion_base_prob" => [0.2 + l * 0.2, 1.0].min
      }
    }
  end
end
```

Each plugin: test file first, then implementation, then register in index.html and test_helper.rb.

### Phase 4: Documentation and Tasks Update

1. Update tasks.md to mark plugin system task as done
2. Ensure all 371+ tests still pass

### Phase 5: Commit and Push

1. Single atomic commit with all changes
2. Push to `claude/merge-vj-pad-branches-evSTE`

## File Changes Summary

| File | Action |
|---|---|
| src/ruby/vj_pad.rb | Add `plugins` command |
| src/ruby/effect_dispatcher.rb | Add `set_param` dispatch |
| src/ruby/plugins/vj_shockwave.rb | New plugin |
| src/ruby/plugins/vj_strobe.rb | New plugin |
| src/ruby/plugins/vj_rave.rb | New plugin |
| test/test_vj_pad.rb | Add plugins command test |
| test/test_effect_dispatcher.rb | Add set_param test |
| test/test_vj_shockwave.rb | New test file |
| test/test_vj_strobe.rb | New test file |
| test/test_vj_rave.rb | New test file |
| test/test_helper.rb | Add new plugin requires |
| index.html | Add new plugin script tags |
| .claude/tasks.md | Update task status |

## Risk Assessment

- LOW: All changes are additive (no modification of existing behavior)
- Plugin system is proven (burst/flash already work)
- `set_param` effect type is new but well-scoped
- Each step is independently testable
