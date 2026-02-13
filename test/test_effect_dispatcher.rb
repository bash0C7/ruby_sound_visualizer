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
end
