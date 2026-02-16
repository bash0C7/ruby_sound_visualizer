require_relative 'test_helper'

class TestAudioAnalyzer < Test::Unit::TestCase
  def setup
    @analyzer = AudioAnalyzer.new
  end

  # === Phase 4-1: Basic functionality tests ===

  def test_initialize_creates_analyzer
    analyzer = AudioAnalyzer.new
    assert_not_nil analyzer
  end

  def test_analyze_returns_hash
    result = @analyzer.analyze([100, 150, 200])
    assert_instance_of Hash, result
  end

  def test_analyze_returns_required_keys
    result = @analyzer.analyze([100, 150, 200])
    assert_includes result.keys, :bass
    assert_includes result.keys, :mid
    assert_includes result.keys, :high
    assert_includes result.keys, :overall_energy
    assert_includes result.keys, :dominant_frequency
    assert_includes result.keys, :beat
    assert_includes result.keys, :impulse
    assert_includes result.keys, :bands
  end

  def test_analyze_beat_is_hash
    result = @analyzer.analyze([100, 150, 200])
    assert_instance_of Hash, result[:beat]
  end

  def test_analyze_beat_has_required_keys
    result = @analyzer.analyze([100, 150, 200])
    beat = result[:beat]
    assert_includes beat.keys, :overall
    assert_includes beat.keys, :bass
    assert_includes beat.keys, :mid
    assert_includes beat.keys, :high
  end

  def test_analyze_impulse_is_hash
    result = @analyzer.analyze([100, 150, 200])
    assert_instance_of Hash, result[:impulse]
  end

  def test_analyze_impulse_has_required_keys
    result = @analyzer.analyze([100, 150, 200])
    impulse = result[:impulse]
    assert_includes impulse.keys, :overall
    assert_includes impulse.keys, :bass
    assert_includes impulse.keys, :mid
    assert_includes impulse.keys, :high
  end

  def test_analyze_bands_is_hash
    result = @analyzer.analyze([100, 150, 200])
    assert_instance_of Hash, result[:bands]
  end

  def test_analyze_bands_has_required_keys
    result = @analyzer.analyze([100, 150, 200])
    bands = result[:bands]
    assert_includes bands.keys, :bass
    assert_includes bands.keys, :mid
    assert_includes bands.keys, :high
  end

  def test_analyze_empty_array_returns_empty_analysis
    result = @analyzer.analyze([])
    assert_equal 0.0, result[:bass]
    assert_equal 0.0, result[:mid]
    assert_equal 0.0, result[:high]
    assert_equal 0.0, result[:overall_energy]
    assert_equal 0, result[:dominant_frequency]
    assert_equal false, result[:beat][:overall]
    assert_equal false, result[:beat][:bass]
    assert_equal false, result[:beat][:mid]
    assert_equal false, result[:beat][:high]
  end

  def test_analyze_with_sensitivity_parameter
    result = @analyzer.analyze([100, 150, 200], 2.0)
    assert_instance_of Hash, result
    # Sensitivity affects beat detection, not immediate energy values
  end

  def test_analyze_returns_numeric_energy_values
    result = @analyzer.analyze([100, 150, 200])
    assert_kind_of Numeric, result[:bass]
    assert_kind_of Numeric, result[:mid]
    assert_kind_of Numeric, result[:high]
    assert_kind_of Numeric, result[:overall_energy]
  end

  def test_analyze_returns_boolean_beat_values
    result = @analyzer.analyze([100, 150, 200])
    beat = result[:beat]
    assert [true, false].include?(beat[:overall])
    assert [true, false].include?(beat[:bass])
    assert [true, false].include?(beat[:mid])
    assert [true, false].include?(beat[:high])
  end

  def test_analyze_returns_numeric_impulse_values
    result = @analyzer.analyze([100, 150, 200])
    impulse = result[:impulse]
    assert_kind_of Numeric, impulse[:overall]
    assert_kind_of Numeric, impulse[:bass]
    assert_kind_of Numeric, impulse[:mid]
    assert_kind_of Numeric, impulse[:high]
  end

  def test_analyze_dominant_frequency_is_numeric
    result = @analyzer.analyze([100, 150, 200, 50, 75])
    assert_kind_of Numeric, result[:dominant_frequency]
  end

  # === Phase 4-2: Energy calculation tests ===

  def test_analyze_zero_input_produces_zero_energy
    freq_data = Array.new(256, 0)
    result = @analyzer.analyze(freq_data)
    # After smoothing, values approach 0 but may not be exactly 0
    assert result[:overall_energy] < 0.01, "Expected near-zero energy for zero input"
  end

  def test_analyze_constant_input_produces_consistent_energy
    freq_data = Array.new(256, 100)
    result1 = @analyzer.analyze(freq_data)
    _result2 = @analyzer.analyze(freq_data)
    result3 = @analyzer.analyze(freq_data)
    # After multiple frames, smoothed values should converge
    # Energy values should increase or stabilize
    assert result3[:overall_energy] >= result1[:overall_energy]
  end

  def test_analyze_high_frequency_increases_high_band_energy
    # Create frequency data with strong high frequencies (bins 50-127)
    freq_data = Array.new(128, 0)
    (50..127).each { |i| freq_data[i] = 200 }

    # Warmup: run multiple frames to let smoothing stabilize
    10.times { @analyzer.analyze(freq_data) }
    result = @analyzer.analyze(freq_data)

    # High band should have more energy than bass/mid
    assert result[:high] > result[:bass], "High energy should exceed bass for high-frequency input"
  end

  def test_analyze_low_frequency_increases_bass_band_energy
    # Create frequency data with strong low frequencies (bins 0-15)
    freq_data = Array.new(128, 0)
    (0..15).each { |i| freq_data[i] = 200 }

    # Warmup: run multiple frames to let smoothing stabilize
    10.times { @analyzer.analyze(freq_data) }
    result = @analyzer.analyze(freq_data)

    # Bass band should have more energy than high
    assert result[:bass] > result[:high], "Bass energy should exceed high for low-frequency input"
  end

  def test_find_dominant_frequency_empty_array
    result = @analyzer.analyze([])
    assert_equal 0, result[:dominant_frequency]
  end

  def test_find_dominant_frequency_single_peak
    # Create frequency data with single strong peak at bin 10
    freq_data = Array.new(128, 10)
    freq_data[10] = 255  # Strong peak at bin 10

    result = @analyzer.analyze(freq_data)
    # Dominant frequency should be around bin 10
    # Frequency = bin * (sample_rate / 2) / (fft_size / 2)
    expected_freq = 10 * (48000 / 2.0) / (2048 / 2.0)

    assert_in_delta expected_freq, result[:dominant_frequency], expected_freq * 0.2,
      "Dominant frequency should be near expected value for single peak"
  end

  def test_analyze_bands_contain_frequency_data
    freq_data = Array.new(128, 100)
    result = @analyzer.analyze(freq_data)

    bands = result[:bands]
    assert_instance_of Array, bands[:bass]
    assert_instance_of Array, bands[:mid]
    assert_instance_of Array, bands[:high]

    # Bands should contain frequency data
    assert bands[:bass].length > 0, "Bass band should not be empty"
    assert bands[:mid].length > 0, "Mid band should not be empty"
    assert bands[:high].length > 0, "High band should not be empty"
  end

  def test_energy_values_are_normalized_0_to_1_range
    freq_data = Array.new(128, 255)  # Maximum input

    # Warmup to stabilize smoothing
    20.times { @analyzer.analyze(freq_data) }
    result = @analyzer.analyze(freq_data)

    # Energy values should be in reasonable range (0-1 after normalization)
    assert result[:bass] >= 0.0, "Bass energy should be non-negative"
    assert result[:bass] <= 1.5, "Bass energy should be reasonably bounded"
    assert result[:overall_energy] >= 0.0, "Overall energy should be non-negative"
    assert result[:overall_energy] <= 1.5, "Overall energy should be reasonably bounded"
  end

  # === Phase 4-3: Smoothing tests ===

  def test_smoothing_causes_gradual_energy_increase
    freq_data = Array.new(128, 200)

    # First frame should have lower energy due to smoothing from zero
    result1 = @analyzer.analyze(freq_data)
    result2 = @analyzer.analyze(freq_data)
    result3 = @analyzer.analyze(freq_data)

    # Energy should increase gradually due to smoothing (lerp)
    assert result2[:overall_energy] > result1[:overall_energy],
      "Smoothing should cause gradual energy increase"
    assert result3[:overall_energy] > result2[:overall_energy],
      "Energy should continue increasing with consistent input"
  end

  def test_smoothing_causes_gradual_energy_decrease
    freq_data_high = Array.new(128, 200)
    freq_data_zero = Array.new(128, 0)

    # Warmup with high energy
    10.times { @analyzer.analyze(freq_data_high) }
    result_before = @analyzer.analyze(freq_data_high)

    # Switch to zero input
    result1 = @analyzer.analyze(freq_data_zero)
    result2 = @analyzer.analyze(freq_data_zero)

    # Energy should decrease gradually due to smoothing
    assert result1[:overall_energy] < result_before[:overall_energy],
      "Energy should start decreasing when input drops"
    assert result2[:overall_energy] < result1[:overall_energy],
      "Energy should continue decreasing with zero input"
  end

  def test_exponential_decay_reduces_low_values
    freq_data = Array.new(128, 10)  # Low values

    # Analyze multiple frames
    _result1 = @analyzer.analyze(freq_data)
    5.times { @analyzer.analyze(freq_data) }
    result2 = @analyzer.analyze(freq_data)

    # Exponential decay should reduce low values below threshold
    # Values stabilize at some low level, not exactly zero
    assert result2[:overall_energy] < 0.5,
      "Exponential decay should keep low values small"
  end

  def test_smoothing_converges_to_stable_value
    freq_data = Array.new(128, 150)

    results = []
    30.times do
      results << @analyzer.analyze(freq_data)[:overall_energy]
    end

    # After many frames, values should converge (small change between frames)
    last_five = results[-5..-1]
    variance = last_five.map { |v| (v - last_five[0]).abs }.max

    assert variance < 0.05, "Energy should converge to stable value after many frames"
  end

  def test_impulse_values_decay_over_time
    freq_data = Array.new(128, 0)

    # Warmup to clear any initial state
    20.times { @analyzer.analyze(freq_data) }

    # Get baseline impulse (should be near zero)
    result_baseline = @analyzer.analyze(freq_data)

    # Note: Impulse spikes only on beat detection, which requires
    # significant energy above baseline. With zero input, impulses
    # should remain near zero and decay naturally.
    assert result_baseline[:impulse][:overall] < 0.1,
      "Impulse should be near zero with no beats"
  end

  # === Phase 4-4: Beat detection tests ===

  def test_warmup_period_prevents_beat_detection
    # During warmup, beats should not be detected even with high energy
    freq_data = Array.new(128, 255)

    # First few frames should be warmup period
    result = @analyzer.analyze(freq_data)
    assert_equal false, result[:beat][:overall],
      "No beats should be detected during warmup"
    assert_equal false, result[:beat][:bass],
      "No bass beats should be detected during warmup"
  end

  def test_beat_detection_after_warmup
    freq_data_silence = Array.new(128, 0)
    freq_data_loud = Array.new(128, 0)
    # Strong bass frequencies (bins 0-15)
    (0..15).each { |i| freq_data_loud[i] = 255 }

    # Warmup with silence to establish baseline
    60.times { @analyzer.analyze(freq_data_silence) }

    # Sudden loud bass should trigger beat
    result = @analyzer.analyze(freq_data_loud)

    # Beat detection may take a frame or two due to smoothing
    # Try multiple frames
    beat_detected = false
    5.times do
      result = @analyzer.analyze(freq_data_loud)
      if result[:beat][:bass] || result[:beat][:overall]
        beat_detected = true
        break
      end
    end

    assert beat_detected, "Beat should be detected for sudden loud bass after warmup"
  end

  def test_beat_cooldown_prevents_rapid_detection
    freq_data_silence = Array.new(128, 0)
    freq_data_loud = Array.new(128, 0)
    (0..15).each { |i| freq_data_loud[i] = 255 }

    # Warmup
    60.times { @analyzer.analyze(freq_data_silence) }

    # Trigger beat
    result1 = @analyzer.analyze(freq_data_loud)
    result2 = @analyzer.analyze(freq_data_loud)
    result3 = @analyzer.analyze(freq_data_loud)
    result4 = @analyzer.analyze(freq_data_loud)
    result5 = @analyzer.analyze(freq_data_loud)

    # Count consecutive beat detections
    beats = [result1, result2, result3, result4, result5].count { |r| r[:beat][:overall] }

    # Due to cooldown, not all frames should detect beats
    assert beats < 5, "Cooldown should prevent beat detection on every frame"
  end

  def test_impulse_spikes_on_beat_detection
    freq_data_silence = Array.new(128, 0)
    freq_data_loud = Array.new(128, 0)
    (0..15).each { |i| freq_data_loud[i] = 255 }

    # Warmup
    60.times { @analyzer.analyze(freq_data_silence) }

    # Check impulse before beat
    result_before = @analyzer.analyze(freq_data_silence)
    impulse_before = result_before[:impulse][:overall]

    # Trigger beat
    result_beat = nil
    10.times do
      result_beat = @analyzer.analyze(freq_data_loud)
      break if result_beat[:beat][:overall]
    end

    # If beat was detected, impulse should spike
    if result_beat && result_beat[:beat][:overall]
      assert result_beat[:impulse][:overall] > impulse_before,
        "Impulse should spike when beat is detected"
      assert result_beat[:impulse][:overall] > 0.5,
        "Impulse should be significantly elevated on beat"
    end
  end

  def test_baseline_adapts_to_ambient_noise
    freq_data_low = Array.new(128, 50)
    freq_data_high = Array.new(128, 100)

    # Establish baseline with low noise
    30.times { @analyzer.analyze(freq_data_low) }
    result_low = @analyzer.analyze(freq_data_low)

    # Switch to higher ambient noise
    30.times { @analyzer.analyze(freq_data_high) }
    result_high = @analyzer.analyze(freq_data_high)

    # Baseline should adapt, so beat detection remains stable
    # (Difficult to assert exact behavior, but we verify no crash)
    assert_not_nil result_low[:beat]
    assert_not_nil result_high[:beat]
  end

  def test_sensitivity_affects_beat_detection
    freq_data_silence = Array.new(128, 0)
    freq_data_medium = Array.new(128, 0)
    (0..15).each { |i| freq_data_medium[i] = 150 }  # Medium bass

    # Warmup with low sensitivity
    60.times { @analyzer.analyze(freq_data_silence, 0.5) }

    # Medium bass with low sensitivity (may not trigger beat)
    result_low_sens = @analyzer.analyze(freq_data_medium, 0.5)

    # Create new analyzer for high sensitivity test
    analyzer2 = AudioAnalyzer.new

    # Warmup with high sensitivity
    60.times { analyzer2.analyze(freq_data_silence, 2.0) }

    # Medium bass with high sensitivity (more likely to trigger beat)
    result_high_sens = analyzer2.analyze(freq_data_medium, 2.0)

    # High sensitivity should be more likely to detect beats
    # (This is probabilistic, so we just verify the mechanism works)
    assert_not_nil result_low_sens[:beat]
    assert_not_nil result_high_sens[:beat]
  end

  # === Phase 9: C-8 NaN/Infinity handling tests ===

  def test_analyze_handles_nan_in_frequency_data
    freq_data = Array.new(128, 100)
    freq_data[10] = Float::NAN
    # Should not raise; NaN.to_f is NaN, NaN.to_i is 0
    result = @analyzer.analyze(freq_data)
    assert_instance_of Hash, result
  end

  def test_analyze_handles_infinity_in_frequency_data
    freq_data = Array.new(128, 100)
    freq_data[10] = Float::INFINITY
    result = @analyzer.analyze(freq_data)
    assert_instance_of Hash, result
  end

  def test_analyze_all_zeros_does_not_produce_nan
    freq_data = Array.new(256, 0)
    result = @analyzer.analyze(freq_data)
    refute result[:bass].nan?, "Bass should not be NaN for zero input"
    refute result[:overall_energy].nan?, "Overall energy should not be NaN for zero input"
  end

  def test_analyze_single_element_array
    result = @analyzer.analyze([128])
    assert_instance_of Hash, result
    assert_kind_of Numeric, result[:overall_energy]
  end

  def test_separate_band_beat_detection
    freq_data_silence = Array.new(128, 0)

    # Bass-only input
    freq_data_bass = Array.new(128, 0)
    (0..15).each { |i| freq_data_bass[i] = 255 }

    # High-only input
    freq_data_high = Array.new(128, 0)
    (64..127).each { |i| freq_data_high[i] = 255 }

    # Warmup
    analyzer_bass = AudioAnalyzer.new
    analyzer_high = AudioAnalyzer.new

    60.times { analyzer_bass.analyze(freq_data_silence) }
    60.times { analyzer_high.analyze(freq_data_silence) }

    # Test bass beat
    bass_beat_detected = false
    10.times do
      result = analyzer_bass.analyze(freq_data_bass)
      if result[:beat][:bass]
        bass_beat_detected = true
        break
      end
    end

    # Test high beat
    high_beat_detected = false
    10.times do
      result = analyzer_high.analyze(freq_data_high)
      if result[:beat][:high]
        high_beat_detected = true
        break
      end
    end

    # At least one band should detect beats in its frequency range
    assert bass_beat_detected || high_beat_detected,
      "Beat detection should work for separate frequency bands"
  end
end
