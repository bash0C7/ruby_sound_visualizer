require_relative 'test_helper'

class TestAutoCalibrator < Test::Unit::TestCase
  def setup
    JS.reset_global!
    VisualizerPolicy.reset_runtime
    ColorPalette.set_hue_mode(nil)
    ColorPalette.set_hue_offset(0.0)
    @calibrator = AutoCalibrator.new
  end

  # === State machine tests ===

  def test_initial_state_is_idle
    assert_equal :idle, @calibrator.state
  end

  def test_initial_progress_is_zero
    assert_in_delta 0.0, @calibrator.progress, 0.001
  end

  def test_initial_intensity_level_is_zero
    assert_equal 0, @calibrator.intensity_level
  end

  def test_start_transitions_to_measuring
    @calibrator.start
    assert_equal :measuring, @calibrator.state
  end

  def test_progress_increases_during_measurement
    @calibrator.start
    10.times { @calibrator.feed(make_analysis(overall: 0.3)) }
    assert @calibrator.progress > 0.0
    assert @calibrator.progress < 1.0
  end

  def test_completes_after_duration_frames
    complete_calibration(0.3)
    assert_equal :done, @calibrator.state
    assert_in_delta 1.0, @calibrator.progress, 0.01
  end

  def test_feed_ignored_when_idle
    @calibrator.feed(make_analysis(overall: 0.5))
    assert_equal :idle, @calibrator.state
    assert_in_delta 0.0, @calibrator.progress, 0.001
  end

  def test_feed_ignored_when_done
    complete_calibration(0.3)
    old_params = @calibrator.baseline_params.dup
    @calibrator.feed(make_analysis(overall: 0.9))
    assert_equal old_params, @calibrator.baseline_params
  end

  def test_start_resets_previous_calibration
    complete_calibration(0.3)
    @calibrator.start
    assert_equal :measuring, @calibrator.state
    assert_in_delta 0.0, @calibrator.progress, 0.001
  end

  # === calculate() pure function tests ===

  def test_calculate_returns_hash
    measurements = Array.new(100) { make_measurement(overall: 0.3) }
    result = @calibrator.calculate(measurements)
    assert_instance_of Hash, result
  end

  def test_calculate_includes_key_params
    measurements = Array.new(100) { make_measurement(overall: 0.3) }
    result = @calibrator.calculate(measurements)
    assert result.key?('input_gain'), 'Should include input_gain'
    assert result.key?('sensitivity'), 'Should include sensitivity'
    assert result.key?('bloom_base_strength'), 'Should include bloom_base_strength'
    assert result.key?('bloom_energy_scale'), 'Should include bloom_energy_scale'
  end

  def test_calculate_silent_input_boosts_gain
    measurements = Array.new(100) { make_measurement(overall: 0.01) }
    result = @calibrator.calculate(measurements)
    assert result['input_gain'] > 0.0, "Silent input should boost gain, got #{result['input_gain']}"
  end

  def test_calculate_loud_input_reduces_gain
    measurements = Array.new(100) { make_measurement(overall: 0.8) }
    result = @calibrator.calculate(measurements)
    assert result['input_gain'] < 0.0, "Loud input should reduce gain, got #{result['input_gain']}"
  end

  def test_calculate_medium_input_near_default_gain
    measurements = Array.new(100) { make_measurement(overall: AutoCalibrator::TARGET_ENERGY) }
    result = @calibrator.calculate(measurements)
    assert_in_delta 0.0, result['input_gain'], 3.0,
                    "Medium input should have near-zero gain, got #{result['input_gain']}"
  end

  def test_calculate_params_within_valid_ranges
    [0.01, 0.1, 0.3, 0.5, 0.8].each do |energy|
      measurements = Array.new(100) { make_measurement(overall: energy) }
      result = @calibrator.calculate(measurements)

      VisualizerPolicy::RUNTIME_PARAMS.each do |name, spec|
        next unless result.key?(name.to_s)

        val = result[name.to_s]
        if spec[:min]
          assert val >= spec[:min],
                 "#{name}=#{val} below min #{spec[:min]} for energy=#{energy}"
        end
        if spec[:max]
          assert val <= spec[:max],
                 "#{name}=#{val} above max #{spec[:max]} for energy=#{energy}"
        end
      end
    end
  end

  def test_calculate_is_deterministic
    measurements = Array.new(100) { make_measurement(overall: 0.3) }
    result1 = @calibrator.calculate(measurements)
    result2 = @calibrator.calculate(measurements)
    assert_equal result1, result2
  end

  # === apply_baseline() tests ===

  def test_apply_baseline_returns_empty_when_idle
    result = @calibrator.apply_baseline
    assert_equal({}, result)
  end

  def test_apply_baseline_returns_empty_when_measuring
    @calibrator.start
    5.times { @calibrator.feed(make_analysis(overall: 0.3)) }
    result = @calibrator.apply_baseline
    assert_equal({}, result)
  end

  def test_apply_baseline_sets_policy_params
    complete_calibration(0.1)
    result = @calibrator.apply_baseline
    assert result.length > 0, 'Should return changed params'
    assert_in_delta result['input_gain'], VisualizerPolicy.input_gain, 0.01,
                    'apply_baseline should set VisualizerPolicy.input_gain'
  end

  def test_apply_baseline_quiet_input_boosts_gain
    complete_calibration(0.05)
    @calibrator.apply_baseline
    assert VisualizerPolicy.input_gain > 0.0,
           "Quiet input should boost gain, got #{VisualizerPolicy.input_gain}"
  end

  def test_apply_baseline_returns_valid_policy_keys
    complete_calibration(0.3)
    result = @calibrator.apply_baseline
    result.each_key do |key|
      assert VisualizerPolicy::MUTABLE_KEYS.key?(key),
             "Changed param '#{key}' should be a valid MUTABLE_KEYS entry"
    end
  end

  # === intensity_params() pure function tests ===

  def test_intensity_level_zero_returns_baseline
    baseline = {
      'bloom_base_strength' => 0.5,
      'bloom_energy_scale' => 1.0,
      'max_emissive' => 2.0
    }
    result = @calibrator.intensity_params(0, baseline)
    baseline.each do |key, val|
      assert_in_delta val, result[key], 0.001,
                      "Level 0 should match baseline for #{key}"
    end
  end

  def test_intensity_positive_increases_bloom
    baseline = {
      'bloom_base_strength' => 0.5,
      'bloom_energy_scale' => 1.0,
      'max_emissive' => 2.0
    }
    result = @calibrator.intensity_params(3, baseline)
    assert result['bloom_base_strength'] > baseline['bloom_base_strength'],
           'Positive intensity should increase bloom_base_strength'
    assert result['max_emissive'] > baseline['max_emissive'],
           'Positive intensity should increase max_emissive'
  end

  def test_intensity_negative_decreases_bloom
    baseline = {
      'bloom_base_strength' => 0.5,
      'bloom_energy_scale' => 1.0,
      'max_emissive' => 2.0
    }
    result = @calibrator.intensity_params(-3, baseline)
    assert result['bloom_base_strength'] < baseline['bloom_base_strength'],
           'Negative intensity should decrease bloom_base_strength'
    assert result['max_emissive'] < baseline['max_emissive'],
           'Negative intensity should decrease max_emissive'
  end

  def test_intensity_clamped_to_range
    @calibrator.set_intensity(10)
    assert_equal 5, @calibrator.intensity_level
    @calibrator.set_intensity(-10)
    assert_equal(-5, @calibrator.intensity_level)
  end

  def test_intensity_params_within_valid_ranges
    baseline = {
      'bloom_base_strength' => 0.5,
      'bloom_energy_scale' => 1.0,
      'max_emissive' => 2.0,
      'particle_explosion_base_prob' => 0.2,
      'impulse_decay' => 0.82,
      'bloom_impulse_scale' => 1.5
    }

    (-5..5).each do |level|
      result = @calibrator.intensity_params(level, baseline)
      result.each do |key, val|
        spec = VisualizerPolicy::RUNTIME_PARAMS[key.to_sym]
        next unless spec

        if spec[:min]
          assert val >= spec[:min],
                 "#{key}=#{val} below min #{spec[:min]} at level #{level}"
        end
        if spec[:max]
          assert val <= spec[:max],
                 "#{key}=#{val} above max #{spec[:max]} at level #{level}"
        end
      end
    end
  end

  def test_intensity_monotonically_increases
    baseline = {
      'bloom_base_strength' => 0.5,
      'bloom_energy_scale' => 1.0,
      'max_emissive' => 2.0
    }
    prev_bloom = -Float::INFINITY
    (-5..5).each do |level|
      result = @calibrator.intensity_params(level, baseline)
      assert result['bloom_base_strength'] >= prev_bloom,
             "bloom_base_strength should increase with level (level=#{level})"
      prev_bloom = result['bloom_base_strength']
    end
  end

  def test_set_intensity_applies_to_policy
    complete_calibration(0.3)
    @calibrator.apply_baseline
    original_emissive = VisualizerPolicy.max_emissive
    @calibrator.set_intensity(5)
    assert VisualizerPolicy.max_emissive >= original_emissive,
           'Intensity +5 should increase max_emissive'
  end

  def test_set_intensity_after_calibration_updates_all_intensity_keys
    complete_calibration(0.3)
    @calibrator.apply_baseline
    original_emissive = VisualizerPolicy.max_emissive
    original_impulse_scale = VisualizerPolicy.bloom_impulse_scale
    original_impulse_decay = VisualizerPolicy.impulse_decay

    @calibrator.set_intensity(5)

    assert VisualizerPolicy.max_emissive > original_emissive,
           'Intensity +5 after calibration should increase max_emissive'
    assert VisualizerPolicy.bloom_impulse_scale > original_impulse_scale,
           'Intensity +5 after calibration should increase bloom_impulse_scale'
    assert VisualizerPolicy.impulse_decay > original_impulse_decay,
           'Intensity +5 after calibration should increase impulse_decay'
  end

  def test_set_intensity_works_without_calibration
    # Should use defaults as baseline
    @calibrator.set_intensity(3)
    assert_equal 3, @calibrator.intensity_level
  end

  # === Color Mood preset tests ===

  def test_mood_red_preset
    params = AutoCalibrator.mood_params(:red)
    assert_equal 1, params[:hue_mode]
    assert_in_delta 0.0, params[:hue_offset], 1.0
    assert_equal 100, params[:max_saturation]
    assert params[:max_emissive] > 2.0, 'Vivid red should have high emissive'
  end

  def test_mood_yellow_preset
    params = AutoCalibrator.mood_params(:yellow)
    assert_equal 2, params[:hue_mode]
    assert_in_delta 0.0, params[:hue_offset], 1.0
    assert_equal 100, params[:max_saturation]
  end

  def test_mood_green_preset
    params = AutoCalibrator.mood_params(:green)
    # Green ~ 120 degrees: mode=2 (base=60) + offset=60
    assert_equal 2, params[:hue_mode]
    assert_in_delta 60.0, params[:hue_offset], 1.0
    assert_equal 100, params[:max_saturation]
  end

  def test_mood_blue_preset
    params = AutoCalibrator.mood_params(:blue)
    # Blue ~ 240 degrees: mode=3 (base=180) + offset=60
    assert_equal 3, params[:hue_mode]
    assert_in_delta 60.0, params[:hue_offset], 1.0
    assert_equal 100, params[:max_saturation]
  end

  def test_mood_neon_preset
    params = AutoCalibrator.mood_params(:neon)
    assert_equal 100, params[:max_saturation]
    assert params[:max_emissive] >= 3.5, 'Neon should have very high emissive'
    assert_equal 255, params[:max_brightness]
  end

  def test_mood_unknown_returns_empty
    params = AutoCalibrator.mood_params(:nonexistent)
    assert_equal({}, params)
  end

  def test_mood_all_presets_have_required_keys
    %i[red yellow green blue neon].each do |mood|
      params = AutoCalibrator.mood_params(mood)
      assert params.key?(:hue_mode), "#{mood} should have :hue_mode"
      assert params.key?(:max_saturation), "#{mood} should have :max_saturation"
      assert params.key?(:max_emissive), "#{mood} should have :max_emissive"
      assert params.key?(:max_brightness), "#{mood} should have :max_brightness"
      assert params.key?(:max_lightness), "#{mood} should have :max_lightness"
      assert params.key?(:hue_offset), "#{mood} should have :hue_offset"
    end
  end

  def test_apply_mood_sets_color_palette
    AutoCalibrator.apply_mood(:red)
    assert_equal 1, ColorPalette.get_hue_mode
    assert_equal 100, VisualizerPolicy.max_saturation
  end

  def test_apply_mood_sets_vivid_parameters
    AutoCalibrator.apply_mood(:neon)
    assert VisualizerPolicy.max_emissive >= 3.5
    assert_equal 100, VisualizerPolicy.max_saturation
    assert_equal 255, VisualizerPolicy.max_brightness
  end

  def test_apply_mood_returns_applied_params
    result = AutoCalibrator.apply_mood(:red)
    assert_instance_of Hash, result
    assert result.key?(:hue_mode)
  end

  # === Full integration flow ===

  def test_full_calibration_flow
    @calibrator.start
    assert_equal :measuring, @calibrator.state

    AutoCalibrator::MEASUREMENT_DURATION_FRAMES.times do
      @calibrator.feed(make_analysis(overall: 0.15, bass: 0.2, mid: 0.1, high: 0.05))
    end

    assert_equal :done, @calibrator.state
    @calibrator.apply_baseline

    # Quiet input should have boosted gain
    assert VisualizerPolicy.input_gain > 0.0,
           "Quiet input should boost gain, got #{VisualizerPolicy.input_gain}"

    # Intensity adjustment should work after calibration
    @calibrator.set_intensity(3)
    assert_equal 3, @calibrator.intensity_level
  end

  def test_calibrate_then_mood_then_intensity
    complete_calibration(0.3)
    @calibrator.apply_baseline
    AutoCalibrator.apply_mood(:red)
    assert_equal 1, ColorPalette.get_hue_mode
    @calibrator.set_intensity(2)
    assert_equal 2, @calibrator.intensity_level
  end

  private

  def make_analysis(bass: 0.2, mid: 0.15, high: 0.1, overall: 0.3)
    {
      bass: bass,
      mid: mid,
      high: high,
      overall_energy: overall,
      dominant_frequency: 440,
      beat: { overall: false, bass: false, mid: false, high: false },
      impulse: { overall: 0.0, bass: 0.0, mid: 0.0, high: 0.0 },
      bands: { bass: [], mid: [], high: [] }
    }
  end

  def make_measurement(bass: 0.2, mid: 0.15, high: 0.1, overall: 0.3)
    {
      bass: bass,
      mid: mid,
      high: high,
      overall: overall,
      beat_bass: false,
      beat_mid: false,
      beat_high: false
    }
  end

  def complete_calibration(energy_level)
    @calibrator.start
    AutoCalibrator::MEASUREMENT_DURATION_FRAMES.times do
      @calibrator.feed(make_analysis(overall: energy_level))
    end
  end
end
