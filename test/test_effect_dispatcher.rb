require_relative 'test_helper'

class TestEffectDispatcher < Test::Unit::TestCase
  def setup
    JS.reset_global!
    @effect_manager = EffectManager.new
    @dispatcher = EffectDispatcher.new(@effect_manager)
  end

  # === Impulse dispatching ===

  def test_dispatch_impulse
    effects = { impulse: { bass: 1.0, mid: 0.5, high: 0.3, overall: 0.8 } }
    @dispatcher.dispatch(effects)

    assert_in_delta 1.0, @effect_manager.impulse_bass, 0.001
    assert_in_delta 0.5, @effect_manager.impulse_mid, 0.001
    assert_in_delta 0.3, @effect_manager.impulse_high, 0.001
    assert_in_delta 0.8, @effect_manager.impulse_overall, 0.001
  end

  def test_dispatch_impulse_partial_keys
    effects = { impulse: { bass: 1.0 } }
    @dispatcher.dispatch(effects)

    assert_in_delta 1.0, @effect_manager.impulse_bass, 0.001
    assert_in_delta 0.0, @effect_manager.impulse_mid, 0.001
  end

  # === Bloom flash dispatching ===

  def test_dispatch_bloom_flash
    effects = { bloom_flash: 2.0 }
    @dispatcher.dispatch(effects)

    assert_in_delta 2.0, @effect_manager.bloom_flash, 0.001
  end

  # === Combined effects ===

  def test_dispatch_combined_effects
    effects = {
      impulse: { bass: 1.0, mid: 1.0, high: 1.0, overall: 1.0 },
      bloom_flash: 1.5
    }
    @dispatcher.dispatch(effects)

    assert_in_delta 1.0, @effect_manager.impulse_bass, 0.001
    assert_in_delta 1.5, @effect_manager.bloom_flash, 0.001
  end

  # === Edge cases ===

  def test_dispatch_empty_effects
    @dispatcher.dispatch({})
    assert_in_delta 0.0, @effect_manager.impulse_bass, 0.001
    assert_in_delta 0.0, @effect_manager.bloom_flash, 0.001
  end

  def test_dispatch_nil_effects
    @dispatcher.dispatch(nil)
    # Should not raise
    assert_in_delta 0.0, @effect_manager.impulse_bass, 0.001
  end

  def test_dispatch_unknown_effect_type_ignored
    effects = { unknown_effect: { value: 42 } }
    @dispatcher.dispatch(effects)
    # Should not raise, unknown keys are silently ignored
    assert_in_delta 0.0, @effect_manager.impulse_bass, 0.001
  end

  # === Multi-action dispatch (simulating VJPad pipeline) ===

  def test_dispatch_multiple_actions_sequentially
    actions = [
      { type: :plugin, name: :burst, effects: { impulse: { bass: 1.0, mid: 1.0, high: 1.0, overall: 1.0 } } },
      { type: :plugin, name: :flash, effects: { bloom_flash: 2.0 } }
    ]

    actions.each { |a| @dispatcher.dispatch(a[:effects]) }

    assert_in_delta 1.0, @effect_manager.impulse_bass, 0.001
    assert_in_delta 2.0, @effect_manager.bloom_flash, 0.001
  end

  def test_dispatch_accumulates_impulse_via_max
    @dispatcher.dispatch({ impulse: { bass: 0.5 } })
    @dispatcher.dispatch({ impulse: { bass: 0.8 } })
    # inject_impulse takes max, so 0.8 wins
    assert_in_delta 0.8, @effect_manager.impulse_bass, 0.001
  end

  # === set_param dispatching ===

  def test_dispatch_set_param_adjusts_policy
    VisualizerPolicy.reset_runtime
    effects = { set_param: { "bloom_base_strength" => 2.5 } }
    @dispatcher.dispatch(effects)
    assert_in_delta 2.5, VisualizerPolicy.bloom_base_strength, 0.001
  end

  def test_dispatch_set_param_multiple_keys
    VisualizerPolicy.reset_runtime
    effects = { set_param: { "bloom_base_strength" => 3.0, "particle_friction" => 0.92 } }
    @dispatcher.dispatch(effects)
    assert_in_delta 3.0, VisualizerPolicy.bloom_base_strength, 0.001
    assert_in_delta 0.92, VisualizerPolicy.particle_friction, 0.001
  end

  def test_dispatch_set_param_ignores_unknown_keys
    effects = { set_param: { "nonexistent_key" => 99.9 } }
    # Should not raise
    @dispatcher.dispatch(effects)
  end

  def test_dispatch_set_param_combined_with_impulse
    VisualizerPolicy.reset_runtime
    effects = {
      impulse: { bass: 1.0, mid: 1.0, high: 1.0, overall: 1.0 },
      set_param: { "bloom_base_strength" => 3.0 }
    }
    @dispatcher.dispatch(effects)
    assert_in_delta 1.0, @effect_manager.impulse_bass, 0.001
    assert_in_delta 3.0, VisualizerPolicy.bloom_base_strength, 0.001
  end

  # === Full pipeline: VJPad -> EffectDispatcher -> EffectManager ===

  def test_full_pipeline_burst_and_flash
    pad = VJPad.new
    pad.burst(1.5)
    pad.flash(3.0)

    pad.consume_actions.each do |action|
      @dispatcher.dispatch(action[:effects])
    end

    assert_in_delta 1.5, @effect_manager.impulse_bass, 0.001
    assert_in_delta 1.5, @effect_manager.impulse_overall, 0.001
    assert_in_delta 3.0, @effect_manager.bloom_flash, 0.001
  end
end

class TestEffectDispatcherLogging < Test::Unit::TestCase
  def setup
    @effect_manager = EffectManager.new
    @dispatcher = EffectDispatcher.new(@effect_manager)
    @log_messages = []
    captured = @log_messages
    mock_console = Object.new
    mock_console.define_singleton_method(:log) { |msg| captured << msg.to_s }
    mock_console.define_singleton_method(:error) { |msg| }
    JS.global['console'] = mock_console
  end

  def teardown
    JS.reset_global!
  end

  def test_logs_impulse_dispatch
    @dispatcher.dispatch({ impulse: { bass: 0.8, mid: 0.3, high: 0.1, overall: 0.6 } })
    ruby_logs = @log_messages.select { |m| m.include?('[Ruby]') }
    assert ruby_logs.any? { |m| m.include?('effect.type=impulse') },
           "Expected log with effect.type=impulse, got: #{ruby_logs.inspect}"
  end

  def test_impulse_log_includes_band_magnitudes
    @dispatcher.dispatch({ impulse: { bass: 0.8, mid: 0.3, high: 0.1, overall: 0.6 } })
    ruby_logs = @log_messages.select { |m| m.include?('[Ruby]') }
    assert ruby_logs.any? { |m| m.include?('effect.bass=') && m.include?('effect.overall=') },
           "Expected log with band magnitudes, got: #{ruby_logs.inspect}"
  end

  def test_logs_bloom_flash_dispatch
    @dispatcher.dispatch({ bloom_flash: 0.9 })
    ruby_logs = @log_messages.select { |m| m.include?('[Ruby]') }
    assert ruby_logs.any? { |m| m.include?('effect.type=bloom_flash') },
           "Expected log with effect.type=bloom_flash, got: #{ruby_logs.inspect}"
  end

  def test_no_log_for_empty_effects
    @dispatcher.dispatch({})
    ruby_logs = @log_messages.select { |m| m.include?('[Ruby]') && m.include?('effect.type=') }
    assert_empty ruby_logs, "Expected no effect log for empty dispatch"
  end
end
