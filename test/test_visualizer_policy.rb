require_relative 'test_helper'

class TestVisualizerPolicy < Test::Unit::TestCase
  def setup
    # Reset runtime config to defaults before each test
    VisualizerPolicy.reset_runtime
  end

  # Test Audio Analysis constants
  def test_audio_constants
    assert_equal 48000, VisualizerPolicy::SAMPLE_RATE
    assert_equal 2048, VisualizerPolicy::FFT_SIZE
    assert_equal 43, VisualizerPolicy::HISTORY_SIZE
    assert_equal 0.02, VisualizerPolicy::BASELINE_RATE
    assert_equal 0.15, VisualizerPolicy::WARMUP_RATE
    assert_equal 30, VisualizerPolicy::WARMUP_FRAMES
  end

  def test_beat_detection_constants
    assert_equal 0.06, VisualizerPolicy::BEAT_BASS_DEVIATION
    assert_equal 0.08, VisualizerPolicy::BEAT_MID_DEVIATION
    assert_equal 0.08, VisualizerPolicy::BEAT_HIGH_DEVIATION
    assert_equal 0.25, VisualizerPolicy::BEAT_MIN_BASS
    assert_equal 0.20, VisualizerPolicy::BEAT_MIN_MID
    assert_equal 0.20, VisualizerPolicy::BEAT_MIN_HIGH
  end

  def test_smoothing_constants
    assert_equal 0.70, VisualizerPolicy::VISUAL_SMOOTHING_FACTOR
    assert_equal 0.55, VisualizerPolicy::AUDIO_SMOOTHING_FACTOR
    assert_equal 0.65, VisualizerPolicy::IMPULSE_DECAY_AUDIO
    assert_equal 0.82, VisualizerPolicy::IMPULSE_DECAY_EFFECT
    assert_equal 0.06, VisualizerPolicy::EXPONENTIAL_THRESHOLD
  end

  def test_particle_constants
    assert_equal 3000, VisualizerPolicy::PARTICLE_COUNT
    assert_equal 0.20, VisualizerPolicy::PARTICLE_EXPLOSION_BASE_PROB
    assert_equal 0.50, VisualizerPolicy::PARTICLE_EXPLOSION_ENERGY_SCALE
    assert_equal 0.55, VisualizerPolicy::PARTICLE_EXPLOSION_FORCE_SCALE
    assert_equal 0.86, VisualizerPolicy::PARTICLE_FRICTION
    assert_equal 10, VisualizerPolicy::PARTICLE_BOUNDARY
    assert_equal 5, VisualizerPolicy::PARTICLE_SPAWN_RANGE
  end

  def test_geometry_constants
    assert_equal 1.0, VisualizerPolicy::GEOMETRY_BASE_SCALE
    assert_equal 2.5, VisualizerPolicy::GEOMETRY_SCALE_MULTIPLIER
    assert_equal 2.0, VisualizerPolicy::GEOMETRY_MAX_EMISSIVE
  end

  def test_bloom_constants
    assert_equal 1.5, VisualizerPolicy::BLOOM_BASE_STRENGTH
    assert_equal 0.0, VisualizerPolicy::BLOOM_BASE_THRESHOLD
    assert_equal 1.5, VisualizerPolicy::BLOOM_MAX_STRENGTH
  end

  # Test runtime config accessors
  def test_sensitivity_accessor
    assert_equal 1.0, VisualizerPolicy.sensitivity

    VisualizerPolicy.sensitivity = 1.5
    assert_equal 1.5, VisualizerPolicy.sensitivity

    # Test minimum clipping (new range: 0.1-1.9)
    VisualizerPolicy.sensitivity = 0.01
    assert_equal 0.1, VisualizerPolicy.sensitivity, "Sensitivity should be clamped to minimum 0.1"

    # Test maximum clipping
    VisualizerPolicy.sensitivity = 5.0
    assert_equal 1.9, VisualizerPolicy.sensitivity, "Sensitivity should be clamped to maximum 1.9"
  end

  def test_input_gain_accessor
    assert_equal 0.0, VisualizerPolicy.input_gain

    VisualizerPolicy.input_gain = 10.0
    assert_equal 10.0, VisualizerPolicy.input_gain

    VisualizerPolicy.input_gain = -10.0
    assert_equal(-10.0, VisualizerPolicy.input_gain)

    # Test clamping
    VisualizerPolicy.input_gain = 25.0
    assert_equal 20.0, VisualizerPolicy.input_gain

    VisualizerPolicy.input_gain = -25.0
    assert_equal(-20.0, VisualizerPolicy.input_gain)
  end

  def test_input_gain_linear
    VisualizerPolicy.input_gain = 0.0
    assert_in_delta 1.0, VisualizerPolicy.input_gain_linear, 0.001

    VisualizerPolicy.input_gain = 20.0
    assert_in_delta 10.0, VisualizerPolicy.input_gain_linear, 0.01

    VisualizerPolicy.input_gain = -20.0
    assert_in_delta 0.1, VisualizerPolicy.input_gain_linear, 0.001
  end

  def test_max_brightness_accessor
    assert_equal 255, VisualizerPolicy.max_brightness

    VisualizerPolicy.max_brightness = 128
    assert_equal 128, VisualizerPolicy.max_brightness

    # Test range clipping
    VisualizerPolicy.max_brightness = 300
    assert_equal 255, VisualizerPolicy.max_brightness, "Max brightness should be clamped to 255"

    VisualizerPolicy.max_brightness = -10
    assert_equal 0, VisualizerPolicy.max_brightness, "Max brightness should be clamped to 0"
  end

  def test_max_lightness_accessor
    assert_equal 255, VisualizerPolicy.max_lightness

    VisualizerPolicy.max_lightness = 128
    assert_equal 128, VisualizerPolicy.max_lightness

    # Test range clipping
    VisualizerPolicy.max_lightness = 300
    assert_equal 255, VisualizerPolicy.max_lightness, "Max lightness should be clamped to 255"

    VisualizerPolicy.max_lightness = -10
    assert_equal 0, VisualizerPolicy.max_lightness, "Max lightness should be clamped to 0"
  end

  # DevTool interface tests
  def test_mutable_keys_defined
    assert VisualizerPolicy::MUTABLE_KEYS.is_a?(Hash)
    assert VisualizerPolicy::MUTABLE_KEYS.key?('sensitivity')
    assert VisualizerPolicy::MUTABLE_KEYS.key?('max_brightness')
    assert VisualizerPolicy::MUTABLE_KEYS.key?('max_lightness')
  end

  def test_set_by_key_sensitivity
    result = VisualizerPolicy.set_by_key('sensitivity', 1.5)
    assert_equal 1.5, VisualizerPolicy.sensitivity
    assert_match(/sensitivity/, result)
  end

  def test_set_by_key_clamps_to_range
    VisualizerPolicy.set_by_key('sensitivity', 999.0)
    assert_equal 1.9, VisualizerPolicy.sensitivity

    VisualizerPolicy.set_by_key('sensitivity', -5.0)
    assert_equal 0.1, VisualizerPolicy.sensitivity
  end

  def test_set_by_key_max_brightness
    VisualizerPolicy.set_by_key('max_brightness', 128)
    assert_equal 128, VisualizerPolicy.max_brightness
  end

  def test_set_by_key_unknown_key
    result = VisualizerPolicy.set_by_key('nonexistent', 42)
    assert_match(/Unknown key/, result)
  end

  def test_get_by_key
    VisualizerPolicy.sensitivity = 1.5
    assert_equal 1.5, VisualizerPolicy.get_by_key('sensitivity')
  end

  def test_get_by_key_unknown
    result = VisualizerPolicy.get_by_key('nonexistent')
    assert_match(/Unknown key/, result)
  end

  def test_list_keys_returns_string
    result = VisualizerPolicy.list_keys
    assert_instance_of String, result
    assert_match(/sensitivity/, result)
    assert_match(/max_brightness/, result)
    assert_match(/max_lightness/, result)
  end

  def test_reset_runtime
    VisualizerPolicy.sensitivity = 5.0
    VisualizerPolicy.max_brightness = 100
    VisualizerPolicy.max_lightness = 100
    VisualizerPolicy.reset_runtime
    assert_equal 1.0, VisualizerPolicy.sensitivity
    assert_equal 255, VisualizerPolicy.max_brightness
    assert_equal 255, VisualizerPolicy.max_lightness
  end

  # New cap methods tests
  def test_exclude_max_accessor
    assert_equal false, VisualizerPolicy.exclude_max
    VisualizerPolicy.exclude_max = true
    assert_equal true, VisualizerPolicy.exclude_max
    VisualizerPolicy.exclude_max = false
    assert_equal false, VisualizerPolicy.exclude_max
  end

  def test_cap_rgb_applies_max_brightness
    VisualizerPolicy.max_brightness = 128
    result = VisualizerPolicy.cap_rgb(1.0, 0.8, 0.6)
    # max_brightness 128 / 255 = 0.502
    assert_in_delta 0.502, result[0], 0.01
    assert_in_delta 0.502, result[1], 0.01
    assert_in_delta 0.502, result[2], 0.01
  end

  def test_cap_rgb_with_exclude_max
    VisualizerPolicy.max_brightness = 128
    VisualizerPolicy.exclude_max = true
    result = VisualizerPolicy.cap_rgb(1.0, 0.8, 0.6)
    # Should not apply cap when exclude_max is true
    assert_equal [1.0, 0.8, 0.6], result
  end

  def test_cap_value_applies_max_lightness
    VisualizerPolicy.max_lightness = 128
    result = VisualizerPolicy.cap_value(1.0)
    # max_lightness 128 / 255 = 0.502
    assert_in_delta 0.502, result, 0.01
  end

  def test_cap_value_with_exclude_max
    VisualizerPolicy.max_lightness = 128
    VisualizerPolicy.exclude_max = true
    result = VisualizerPolicy.cap_value(1.0)
    # Should not apply cap when exclude_max is true
    assert_equal 1.0, result
  end

  def test_cap_emissive_applies_max
    VisualizerPolicy.max_emissive = 1.5
    result = VisualizerPolicy.cap_emissive(3.0)
    assert_equal 1.5, result
  end

  def test_cap_emissive_with_exclude_max
    VisualizerPolicy.max_emissive = 1.5
    VisualizerPolicy.exclude_max = true
    result = VisualizerPolicy.cap_emissive(3.0)
    assert_equal 3.0, result
  end

  def test_cap_bloom_applies_max
    VisualizerPolicy.max_bloom = 3.0
    result = VisualizerPolicy.cap_bloom(5.0)
    assert_equal 3.0, result
  end

  def test_cap_bloom_with_exclude_max
    VisualizerPolicy.max_bloom = 3.0
    VisualizerPolicy.exclude_max = true
    result = VisualizerPolicy.cap_bloom(5.0)
    assert_equal 5.0, result
  end

  def test_max_emissive_accessor
    VisualizerPolicy.max_emissive = 1.5
    assert_equal 1.5, VisualizerPolicy.max_emissive
  end

  def test_max_bloom_accessor
    VisualizerPolicy.max_bloom = 3.5
    assert_equal 3.5, VisualizerPolicy.max_bloom
  end

  # === New mutable audio-reactive parameters ===

  def test_bloom_base_strength_accessor
    assert_equal 1.5, VisualizerPolicy.bloom_base_strength
    VisualizerPolicy.bloom_base_strength = 3.0
    assert_equal 3.0, VisualizerPolicy.bloom_base_strength
    # Clamp to min 0.0
    VisualizerPolicy.bloom_base_strength = -1.0
    assert_equal 0.0, VisualizerPolicy.bloom_base_strength
  end

  def test_bloom_energy_scale_accessor
    assert_equal 2.5, VisualizerPolicy.bloom_energy_scale
    VisualizerPolicy.bloom_energy_scale = 4.0
    assert_equal 4.0, VisualizerPolicy.bloom_energy_scale
  end

  def test_bloom_impulse_scale_accessor
    assert_equal 1.5, VisualizerPolicy.bloom_impulse_scale
    VisualizerPolicy.bloom_impulse_scale = 2.0
    assert_equal 2.0, VisualizerPolicy.bloom_impulse_scale
  end

  def test_particle_explosion_base_prob_accessor
    assert_equal 0.20, VisualizerPolicy.particle_explosion_base_prob
    VisualizerPolicy.particle_explosion_base_prob = 0.5
    assert_equal 0.5, VisualizerPolicy.particle_explosion_base_prob
    # Clamp to max 1.0
    VisualizerPolicy.particle_explosion_base_prob = 1.5
    assert_equal 1.0, VisualizerPolicy.particle_explosion_base_prob
  end

  def test_particle_explosion_energy_scale_accessor
    assert_equal 0.50, VisualizerPolicy.particle_explosion_energy_scale
    VisualizerPolicy.particle_explosion_energy_scale = 1.2
    assert_equal 1.2, VisualizerPolicy.particle_explosion_energy_scale
  end

  def test_particle_explosion_force_scale_accessor
    assert_equal 0.55, VisualizerPolicy.particle_explosion_force_scale
    VisualizerPolicy.particle_explosion_force_scale = 1.0
    assert_equal 1.0, VisualizerPolicy.particle_explosion_force_scale
  end

  def test_particle_friction_accessor
    assert_equal 0.86, VisualizerPolicy.particle_friction
    VisualizerPolicy.particle_friction = 0.75
    assert_equal 0.75, VisualizerPolicy.particle_friction
    # Clamp to range 0.50-0.99
    VisualizerPolicy.particle_friction = 0.3
    assert_equal 0.50, VisualizerPolicy.particle_friction
    VisualizerPolicy.particle_friction = 1.0
    assert_equal 0.99, VisualizerPolicy.particle_friction
  end

  def test_visual_smoothing_accessor
    assert_equal 0.70, VisualizerPolicy.visual_smoothing
    VisualizerPolicy.visual_smoothing = 0.85
    assert_equal 0.85, VisualizerPolicy.visual_smoothing
    # Clamp to range 0.0-0.99
    VisualizerPolicy.visual_smoothing = -0.1
    assert_equal 0.0, VisualizerPolicy.visual_smoothing
    VisualizerPolicy.visual_smoothing = 1.5
    assert_equal 0.99, VisualizerPolicy.visual_smoothing
  end

  def test_impulse_decay_accessor
    assert_equal 0.82, VisualizerPolicy.impulse_decay
    VisualizerPolicy.impulse_decay = 0.90
    assert_equal 0.90, VisualizerPolicy.impulse_decay
    # Clamp to range 0.50-0.99
    VisualizerPolicy.impulse_decay = 0.2
    assert_equal 0.50, VisualizerPolicy.impulse_decay
  end

  # Data-driven: all RUNTIME_PARAMS have MUTABLE_KEYS entry
  VisualizerPolicy::RUNTIME_PARAMS.each_key do |name|
    define_method("test_#{name}_in_mutable_keys") do
      assert VisualizerPolicy::MUTABLE_KEYS.key?(name.to_s),
        "MUTABLE_KEYS should contain '#{name}'"
    end
  end

  # Data-driven: all RUNTIME_PARAMS reset to default
  VisualizerPolicy::RUNTIME_PARAMS.each do |name, spec|
    define_method("test_#{name}_resets_to_default") do
      VisualizerPolicy.reset_runtime
      assert_equal spec[:default], VisualizerPolicy.send(name),
        "#{name} should reset to #{spec[:default]}"
    end
  end

  # Data-driven: set_by_key/get_by_key roundtrip for all params
  # Values within MUTABLE_KEYS slider ranges (set_by_key clamps to these)
  ROUNDTRIP_VALUES = {
    sensitivity: 1.5, input_gain: 5.0, max_brightness: 200, max_lightness: 200,
    max_emissive: 1.5, max_bloom: 3.0, max_saturation: 70, exclude_max: true,
    bloom_base_strength: 2.0, bloom_energy_scale: 3.0, bloom_impulse_scale: 2.0,
    particle_explosion_base_prob: 0.3, particle_explosion_energy_scale: 0.8,
    particle_explosion_force_scale: 0.8, particle_friction: 0.85,
    visual_smoothing: 0.85, impulse_decay: 0.90
  }.freeze

  ROUNDTRIP_VALUES.each do |name, val|
    define_method("test_#{name}_set_get_by_key_roundtrip") do
      VisualizerPolicy.set_by_key(name.to_s, val)
      result = VisualizerPolicy.get_by_key(name.to_s)
      if val.is_a?(TrueClass) || val.is_a?(FalseClass)
        assert_equal val, result
      else
        assert_in_delta val, result, 0.01,
          "set_by_key/get_by_key roundtrip for #{name}"
      end
    end
  end


  # max_saturation tests
  def test_max_saturation_default
    assert_equal 100, VisualizerPolicy.max_saturation
  end

  def test_max_saturation_accessor
    VisualizerPolicy.max_saturation = 50
    assert_equal 50, VisualizerPolicy.max_saturation

    VisualizerPolicy.max_saturation = 150
    assert_equal 100, VisualizerPolicy.max_saturation, "max_saturation should be clamped to 100"

    VisualizerPolicy.max_saturation = -10
    assert_equal 0, VisualizerPolicy.max_saturation, "max_saturation should be clamped to 0"
  end


  def test_cap_saturation_applies_scale
    VisualizerPolicy.max_saturation = 50
    result = VisualizerPolicy.cap_saturation(1.0)
    assert_in_delta 0.5, result, 0.001
  end

  def test_cap_saturation_full_scale
    VisualizerPolicy.max_saturation = 100
    result = VisualizerPolicy.cap_saturation(0.8)
    assert_in_delta 0.8, result, 0.001
  end

  def test_cap_saturation_zero_desaturates
    VisualizerPolicy.max_saturation = 0
    result = VisualizerPolicy.cap_saturation(0.8)
    assert_in_delta 0.0, result, 0.001
  end

  def test_reset_runtime_resets_max_saturation
    VisualizerPolicy.max_saturation = 50
    VisualizerPolicy.reset_runtime
    assert_equal 100, VisualizerPolicy.max_saturation
  end

  def test_list_keys_includes_max_saturation
    result = VisualizerPolicy.list_keys
    assert_match(/max_saturation/, result)
  end
end
