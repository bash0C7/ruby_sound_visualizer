require_relative 'test_helper'

class TestAudioLimiter < Test::Unit::TestCase
  def setup
    @limiter = AudioLimiter.new
  end

  # === Initialization ===

  def test_initialize_creates_limiter
    limiter = AudioLimiter.new
    assert_not_nil limiter
  end

  def test_default_gain_reduction_is_one
    assert_in_delta 1.0, @limiter.gain_reduction, 0.001
  end

  # === Basic pass-through ===

  def test_below_threshold_passes_through
    # Values below threshold should pass through unchanged
    result = @limiter.process(0.5)
    assert_in_delta 0.5, result, 0.01
  end

  def test_zero_energy_passes_through
    result = @limiter.process(0.0)
    assert_in_delta 0.0, result, 0.001
  end

  # === Limiting behavior ===

  def test_above_threshold_is_limited
    # Energy above threshold should be reduced
    result = @limiter.process(1.0)
    assert_operator result, :<, 1.0, "Energy above threshold should be limited"
    assert_operator result, :>, 0.0, "Limited energy should still be positive"
  end

  def test_loud_signal_limited_to_near_threshold
    # Very loud signal should be brought down toward threshold
    result = @limiter.process(2.0)
    assert_operator result, :<=, 1.0, "Very loud signal should be limited below 1.0"
  end

  def test_moderate_signal_below_threshold_unchanged
    result = @limiter.process(0.3)
    assert_in_delta 0.3, result, 0.01
  end

  # === Soft knee behavior ===

  def test_soft_knee_gradual_near_threshold
    # Values near threshold should transition smoothly (not hard clip)
    @limiter.process(0.7)
    @limiter.process(0.85)
    @limiter.process(1.0)

    # Reset for clean test
    limiter2 = AudioLimiter.new
    results = [0.6, 0.7, 0.8, 0.9, 1.0].map { |v| limiter2.process(v) }

    # Output should be monotonically increasing
    results.each_cons(2) do |a, b|
      assert_operator a, :<=, b, "Limiter output should be monotonically increasing"
    end
  end

  # === Release behavior ===

  def test_gain_reduction_recovers_after_loud_signal
    # Loud signal causes gain reduction
    @limiter.process(2.0)
    reduced = @limiter.gain_reduction
    assert_operator reduced, :<, 1.0

    # Process quiet signals - gain should recover
    10.times { @limiter.process(0.1) }
    recovered = @limiter.gain_reduction
    assert_operator recovered, :>, reduced, "Gain should recover after quiet period"
  end

  def test_full_recovery_after_many_quiet_frames
    # Loud signal
    @limiter.process(2.0)

    # Many quiet frames
    50.times { @limiter.process(0.1) }

    assert_in_delta 1.0, @limiter.gain_reduction, 0.05,
      "Gain should fully recover after many quiet frames"
  end

  # === Per-band processing ===

  def test_process_bands_returns_hash
    input = { bass: 0.5, mid: 0.3, high: 0.2, overall: 0.4 }
    result = @limiter.process_bands(input)
    assert_instance_of Hash, result
    assert_includes result.keys, :bass
    assert_includes result.keys, :mid
    assert_includes result.keys, :high
    assert_includes result.keys, :overall
  end

  def test_process_bands_limits_loud_band
    input = { bass: 2.0, mid: 0.3, high: 0.2, overall: 1.5 }
    result = @limiter.process_bands(input)
    assert_operator result[:bass], :<, 2.0, "Loud bass should be limited"
    assert_operator result[:overall], :<, 1.5, "Loud overall should be limited"
  end

  def test_process_bands_preserves_quiet_bands
    input = { bass: 0.3, mid: 0.2, high: 0.1, overall: 0.2 }
    result = @limiter.process_bands(input)
    assert_in_delta 0.3, result[:bass], 0.05
    assert_in_delta 0.2, result[:mid], 0.05
    assert_in_delta 0.1, result[:high], 0.05
  end

  # === Custom threshold ===

  def test_custom_threshold
    limiter = AudioLimiter.new(threshold: 0.5)
    result = limiter.process(0.8)
    # Should start limiting at lower threshold
    assert_operator result, :<, 0.8
  end

  def test_higher_threshold_allows_more_energy
    low_thresh = AudioLimiter.new(threshold: 0.5)
    high_thresh = AudioLimiter.new(threshold: 0.95)

    result_low = low_thresh.process(0.8)
    result_high = high_thresh.process(0.8)

    assert_operator result_low, :<, result_high,
      "Lower threshold should limit more aggressively"
  end

  # === Edge cases ===

  def test_negative_energy_treated_as_zero
    result = @limiter.process(-0.5)
    assert_in_delta 0.0, result, 0.001
  end

  def test_very_large_energy_still_limited
    result = @limiter.process(100.0)
    assert_operator result, :<=, 1.0, "Extreme energy should be heavily limited"
  end

  # === Reset ===

  def test_reset_restores_initial_state
    @limiter.process(2.0)
    assert_operator @limiter.gain_reduction, :<, 1.0

    @limiter.reset
    assert_in_delta 1.0, @limiter.gain_reduction, 0.001
  end
end
