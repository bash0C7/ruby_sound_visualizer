require_relative 'test_helper'

# Parameter contract tests: guard against regressions when multiple features
# (auto-calibration, manual controls, plugins, future features) write to
# the same VisualizerPolicy RUNTIME_PARAMS.
#
# These tests verify:
# 1. Parameter interface stability (names, types, ranges)
# 2. AutoCalibrator only writes valid policy keys
# 3. AutoCalibrator output stays within declared ranges
# 4. Manual override after calibration works correctly
# 5. Mood presets don't corrupt policy state
# 6. Intensity + calibration composition is safe
class TestParameterContract < Test::Unit::TestCase
  def setup
    JS.reset_global!
    VisualizerPolicy.reset_runtime
    ColorPalette.set_hue_mode(nil)
    ColorPalette.set_hue_offset(0.0)
  end

  # === 1. Parameter interface stability ===
  # If any of these fail, a RUNTIME_PARAMS change happened that may break
  # AutoCalibrator, VJPad, SnapshotManager, or UI sliders.

  EXPECTED_PARAM_NAMES = %i[
    sensitivity input_gain max_brightness max_lightness max_saturation
    max_emissive max_bloom exclude_max bloom_base_strength bloom_energy_scale
    bloom_impulse_scale bloom_strength_scale bloom_flash_multiplier
    particle_explosion_base_prob particle_explosion_energy_scale
    particle_explosion_force_scale particle_friction visual_smoothing
    impulse_decay
  ].freeze

  def test_runtime_params_contain_expected_names
    EXPECTED_PARAM_NAMES.each do |name|
      assert VisualizerPolicy::RUNTIME_PARAMS.key?(name),
             "RUNTIME_PARAMS missing expected key: #{name}"
    end
  end

  def test_runtime_params_have_defaults
    VisualizerPolicy::RUNTIME_PARAMS.each do |name, spec|
      assert spec.key?(:default),
             "RUNTIME_PARAMS[:#{name}] missing :default"
    end
  end

  def test_runtime_params_have_types
    VisualizerPolicy::RUNTIME_PARAMS.each do |name, spec|
      assert %i[int float bool].include?(spec[:type]),
             "RUNTIME_PARAMS[:#{name}] has invalid type: #{spec[:type]}"
    end
  end

  def test_all_runtime_params_in_mutable_keys
    VisualizerPolicy::RUNTIME_PARAMS.each_key do |name|
      assert VisualizerPolicy::MUTABLE_KEYS.key?(name.to_s),
             "RUNTIME_PARAMS[:#{name}] not in MUTABLE_KEYS (breaks UI sliders)"
    end
  end

  # === 2. AutoCalibrator output validity ===

  def test_calibrator_output_keys_are_valid_policy_keys
    calibrator = AutoCalibrator.new
    [0.01, 0.1, 0.3, 0.5, 0.8].each do |energy|
      measurements = Array.new(100) { make_measurement(energy) }
      result = calibrator.calculate(measurements)
      result.each_key do |key|
        assert VisualizerPolicy::MUTABLE_KEYS.key?(key),
               "AutoCalibrator output key '#{key}' not in MUTABLE_KEYS (energy=#{energy})"
      end
    end
  end

  def test_calibrator_output_within_runtime_param_ranges
    calibrator = AutoCalibrator.new
    [0.01, 0.1, 0.3, 0.5, 0.8].each do |energy|
      measurements = Array.new(100) { make_measurement(energy) }
      result = calibrator.calculate(measurements)
      assert_params_within_ranges(result, "calibrate(energy=#{energy})")
    end
  end

  # === 3. Intensity output validity ===

  def test_intensity_output_within_ranges_all_levels
    calibrator = AutoCalibrator.new
    baseline = {
      'bloom_base_strength' => 0.5,
      'bloom_energy_scale' => 1.0,
      'bloom_impulse_scale' => 1.5,
      'max_emissive' => 2.0,
      'particle_explosion_base_prob' => 0.2,
      'impulse_decay' => 0.82
    }

    (-5..5).each do |level|
      result = calibrator.intensity_params(level, baseline)
      assert_params_within_ranges(result, "intensity(level=#{level})")
    end
  end

  def test_intensity_with_extreme_baseline_stays_valid
    calibrator = AutoCalibrator.new
    # Baseline at max values
    extreme_baseline = {
      'bloom_base_strength' => 3.0,
      'bloom_energy_scale' => 5.0,
      'bloom_impulse_scale' => 3.0,
      'max_emissive' => 4.0,
      'particle_explosion_base_prob' => 1.0,
      'impulse_decay' => 0.99
    }

    result = calibrator.intensity_params(5, extreme_baseline)
    assert_params_within_ranges(result, 'intensity(level=5, extreme baseline)')
  end

  # === 4. Manual override after calibration ===

  def test_manual_override_after_calibration_works
    calibrator = AutoCalibrator.new
    calibrator.start
    AutoCalibrator::MEASUREMENT_DURATION_FRAMES.times do
      calibrator.feed(make_analysis(0.2))
    end
    calibrator.apply_baseline

    # Manual override should take effect
    VisualizerPolicy.sensitivity = 1.8
    assert_in_delta 1.8, VisualizerPolicy.sensitivity, 0.001,
                    'Manual override should work after calibration'
  end

  def test_intensity_after_manual_override
    calibrator = AutoCalibrator.new
    calibrator.start
    AutoCalibrator::MEASUREMENT_DURATION_FRAMES.times do
      calibrator.feed(make_analysis(0.3))
    end
    calibrator.apply_baseline

    # Manual change to a param not in intensity adjustments
    VisualizerPolicy.max_brightness = 128

    # Intensity should not clobber unrelated params
    calibrator.set_intensity(3)
    assert_equal 128, VisualizerPolicy.max_brightness,
                 'Intensity should not overwrite manually set max_brightness'
  end

  # === 5. Mood preset safety ===

  def test_mood_presets_dont_corrupt_calibration_params
    calibrator = AutoCalibrator.new
    calibrator.start
    AutoCalibrator::MEASUREMENT_DURATION_FRAMES.times do
      calibrator.feed(make_analysis(0.3))
    end
    calibrator.apply_baseline
    saved_gain = VisualizerPolicy.input_gain

    AutoCalibrator.apply_mood(:red)

    # input_gain should not be changed by mood preset
    assert_in_delta saved_gain, VisualizerPolicy.input_gain, 0.001,
                    'Mood preset should not change input_gain'
  end

  def test_mood_preset_values_valid
    AutoCalibrator::MOOD_PRESETS.each do |name, params|
      if params[:max_saturation]
        assert params[:max_saturation] >= 0 && params[:max_saturation] <= 100,
               "#{name} max_saturation out of range: #{params[:max_saturation]}"
      end
      if params[:max_brightness]
        assert params[:max_brightness] >= 0 && params[:max_brightness] <= 255,
               "#{name} max_brightness out of range: #{params[:max_brightness]}"
      end
      if params[:max_lightness]
        assert params[:max_lightness] >= 0 && params[:max_lightness] <= 255,
               "#{name} max_lightness out of range: #{params[:max_lightness]}"
      end
      if params[:hue_mode]
        assert [1, 2, 3].include?(params[:hue_mode]),
               "#{name} hue_mode invalid: #{params[:hue_mode]}"
      end
    end
  end

  # === 6. Reset restores defaults after all operations ===

  def test_reset_restores_defaults_after_calibration_and_mood
    calibrator = AutoCalibrator.new
    calibrator.start
    AutoCalibrator::MEASUREMENT_DURATION_FRAMES.times do
      calibrator.feed(make_analysis(0.1))
    end
    calibrator.apply_baseline
    AutoCalibrator.apply_mood(:neon)
    calibrator.set_intensity(5)

    # Reset should restore everything
    VisualizerPolicy.reset_runtime
    ColorPalette.set_hue_mode(nil)

    VisualizerPolicy::RUNTIME_PARAMS.each do |name, spec|
      actual = VisualizerPolicy.send(name)
      assert_equal spec[:default], actual,
                   "After reset, #{name} should be #{spec[:default]}, got #{actual}"
    end
    assert_nil ColorPalette.get_hue_mode, 'After reset, hue_mode should be nil'
  end

  private

  def make_analysis(energy)
    {
      bass: energy * 0.6,
      mid: energy * 0.3,
      high: energy * 0.1,
      overall_energy: energy,
      dominant_frequency: 440,
      beat: { overall: false, bass: false, mid: false, high: false },
      impulse: { overall: 0.0, bass: 0.0, mid: 0.0, high: 0.0 },
      bands: { bass: [], mid: [], high: [] }
    }
  end

  def make_measurement(energy)
    {
      bass: energy * 0.6,
      mid: energy * 0.3,
      high: energy * 0.1,
      overall: energy,
      beat_bass: false,
      beat_mid: false,
      beat_high: false
    }
  end

  def assert_params_within_ranges(params_hash, context)
    params_hash.each do |key, val|
      spec = VisualizerPolicy::RUNTIME_PARAMS[key.to_sym]
      next unless spec

      if spec[:min]
        assert val >= spec[:min],
               "[#{context}] #{key}=#{val} below min #{spec[:min]}"
      end
      if spec[:max]
        assert val <= spec[:max],
               "[#{context}] #{key}=#{val} above max #{spec[:max]}"
      end
    end
  end
end
