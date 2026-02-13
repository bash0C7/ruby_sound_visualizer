require_relative 'test_helper'

class TestVJPlugin < Test::Unit::TestCase
  def setup
    VJPlugin.reset!
  end

  # === Registration ===

  def test_define_registers_plugin
    VJPlugin.define(:test_effect) do
      desc "A test effect"
    end
    assert VJPlugin.find(:test_effect)
  end

  def test_find_returns_nil_for_unknown
    assert_nil VJPlugin.find(:nonexistent)
  end

  def test_all_returns_registered_plugins
    VJPlugin.define(:effect_a) { desc "A" }
    VJPlugin.define(:effect_b) { desc "B" }
    assert_equal 2, VJPlugin.all.length
    names = VJPlugin.all.map(&:name)
    assert_includes names, :effect_a
    assert_includes names, :effect_b
  end

  def test_reset_clears_registry
    VJPlugin.define(:temp) { desc "temporary" }
    assert VJPlugin.find(:temp)
    VJPlugin.reset!
    assert_nil VJPlugin.find(:temp)
  end

  def test_names_returns_all_registered_names
    VJPlugin.define(:alpha) { desc "A" }
    VJPlugin.define(:beta) { desc "B" }
    names = VJPlugin.names
    assert_includes names, :alpha
    assert_includes names, :beta
  end

  # === Plugin Definition DSL ===

  def test_desc_sets_description
    VJPlugin.define(:described) do
      desc "Trigger a bloom flash"
    end
    plugin = VJPlugin.find(:described)
    assert_equal "Trigger a bloom flash", plugin.description
  end

  def test_param_defines_parameter_with_default
    VJPlugin.define(:parameterized) do
      param :force, default: 1.0
    end
    plugin = VJPlugin.find(:parameterized)
    assert_equal({ force: { default: 1.0, range: nil } }, plugin.params)
  end

  def test_param_with_range
    VJPlugin.define(:ranged) do
      param :intensity, default: 1.0, range: 0.0..5.0
    end
    plugin = VJPlugin.find(:ranged)
    assert_equal 0.0..5.0, plugin.params[:intensity][:range]
  end

  def test_multiple_params
    VJPlugin.define(:multi) do
      param :force, default: 1.0
      param :spread, default: 0.5
    end
    plugin = VJPlugin.find(:multi)
    assert_equal 2, plugin.params.length
    assert plugin.params.key?(:force)
    assert plugin.params.key?(:spread)
  end

  # === Execution ===

  def test_execute_with_defaults
    VJPlugin.define(:simple_burst) do
      param :force, default: 1.0
      on_trigger do |params|
        { impulse: { bass: params[:force], mid: params[:force], high: params[:force], overall: params[:force] } }
      end
    end
    plugin = VJPlugin.find(:simple_burst)
    result = plugin.execute({})
    expected = { impulse: { bass: 1.0, mid: 1.0, high: 1.0, overall: 1.0 } }
    assert_equal expected, result
  end

  def test_execute_with_override
    VJPlugin.define(:custom_burst) do
      param :force, default: 1.0
      on_trigger do |params|
        { impulse: { bass: params[:force], mid: params[:force], high: params[:force], overall: params[:force] } }
      end
    end
    plugin = VJPlugin.find(:custom_burst)
    result = plugin.execute({ force: 2.5 })
    assert_in_delta 2.5, result[:impulse][:bass], 0.001
  end

  def test_execute_clamps_to_range
    VJPlugin.define(:clamped) do
      param :intensity, default: 1.0, range: 0.0..3.0
      on_trigger do |params|
        { bloom_flash: params[:intensity] }
      end
    end
    plugin = VJPlugin.find(:clamped)

    result = plugin.execute({ intensity: 5.0 })
    assert_in_delta 3.0, result[:bloom_flash], 0.001

    result = plugin.execute({ intensity: -1.0 })
    assert_in_delta 0.0, result[:bloom_flash], 0.001
  end

  def test_execute_without_on_trigger_returns_empty_hash
    VJPlugin.define(:no_trigger) do
      desc "No trigger block"
      param :force, default: 1.0
    end
    plugin = VJPlugin.find(:no_trigger)
    result = plugin.execute({})
    assert_equal({}, result)
  end

  def test_execute_converts_string_to_float
    VJPlugin.define(:string_param) do
      param :force, default: 1.0
      on_trigger do |params|
        { impulse: { overall: params[:force] } }
      end
    end
    plugin = VJPlugin.find(:string_param)
    result = plugin.execute({ force: "2.5" })
    assert_in_delta 2.5, result[:impulse][:overall], 0.001
  end

  # === Display Helpers ===

  def test_format_result_no_args
    VJPlugin.define(:boom) do
      desc "Boom effect"
    end
    plugin = VJPlugin.find(:boom)
    assert_equal "boom!", plugin.format_result([])
  end

  def test_format_result_with_args
    VJPlugin.define(:boom2) do
      param :force, default: 1.0
    end
    plugin = VJPlugin.find(:boom2)
    assert_equal "boom2: 2.0", plugin.format_result([2.0])
  end

  def test_format_result_with_multiple_args
    VJPlugin.define(:multi_arg) do
      param :force, default: 1.0
      param :spread, default: 0.5
    end
    plugin = VJPlugin.find(:multi_arg)
    assert_equal "multi_arg: 2.0, 0.8", plugin.format_result([2.0, 0.8])
  end

  # === Duplicate Registration ===

  def test_redefine_replaces_plugin
    VJPlugin.define(:dup) do
      desc "version 1"
    end
    VJPlugin.define(:dup) do
      desc "version 2"
    end
    plugin = VJPlugin.find(:dup)
    assert_equal "version 2", plugin.description
    assert_equal 1, VJPlugin.all.count { |p| p.name == :dup }
  end
end
