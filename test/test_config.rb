require_relative 'test_helper'

class TestConfig < Test::Unit::TestCase
  def setup
    # Reset runtime config to defaults before each test
    Config.sensitivity = 1.0
    Config.max_brightness = 255
    Config.max_lightness = 255
  end

  # Test Audio Analysis constants
  def test_audio_constants
    assert_equal 48000, Config::SAMPLE_RATE
    assert_equal 2048, Config::FFT_SIZE
    assert_equal 43, Config::HISTORY_SIZE
    assert_equal 0.02, Config::BASELINE_RATE
    assert_equal 0.15, Config::WARMUP_RATE
    assert_equal 30, Config::WARMUP_FRAMES
  end

  def test_beat_detection_constants
    assert_equal 0.06, Config::BEAT_BASS_DEVIATION
    assert_equal 0.08, Config::BEAT_MID_DEVIATION
    assert_equal 0.08, Config::BEAT_HIGH_DEVIATION
    assert_equal 0.25, Config::BEAT_MIN_BASS
    assert_equal 0.20, Config::BEAT_MIN_MID
    assert_equal 0.20, Config::BEAT_MIN_HIGH
  end

  def test_smoothing_constants
    assert_equal 0.70, Config::VISUAL_SMOOTHING_FACTOR
    assert_equal 0.55, Config::AUDIO_SMOOTHING_FACTOR
    assert_equal 0.65, Config::IMPULSE_DECAY_AUDIO
    assert_equal 0.82, Config::IMPULSE_DECAY_EFFECT
    assert_equal 0.06, Config::EXPONENTIAL_THRESHOLD
  end

  def test_particle_constants
    assert_equal 3000, Config::PARTICLE_COUNT
    assert_equal 0.20, Config::PARTICLE_EXPLOSION_BASE_PROB
    assert_equal 0.50, Config::PARTICLE_EXPLOSION_ENERGY_SCALE
    assert_equal 0.55, Config::PARTICLE_EXPLOSION_FORCE_SCALE
    assert_equal 0.86, Config::PARTICLE_FRICTION
    assert_equal 10, Config::PARTICLE_BOUNDARY
    assert_equal 5, Config::PARTICLE_SPAWN_RANGE
  end

  def test_geometry_constants
    assert_equal 1.0, Config::GEOMETRY_BASE_SCALE
    assert_equal 2.5, Config::GEOMETRY_SCALE_MULTIPLIER
    assert_equal 2.0, Config::GEOMETRY_MAX_EMISSIVE
  end

  def test_bloom_constants
    assert_equal 1.5, Config::BLOOM_BASE_STRENGTH
    assert_equal 0.0, Config::BLOOM_BASE_THRESHOLD
    assert_equal 1.5, Config::BLOOM_MAX_STRENGTH
  end

  # Test runtime config accessors
  def test_sensitivity_accessor
    assert_equal 1.0, Config.sensitivity

    Config.sensitivity = 2.5
    assert_equal 2.5, Config.sensitivity

    # Test minimum clipping
    Config.sensitivity = 0.01
    assert_equal 0.05, Config.sensitivity, "Sensitivity should be clamped to minimum 0.05"
  end

  def test_max_brightness_accessor
    assert_equal 255, Config.max_brightness

    Config.max_brightness = 128
    assert_equal 128, Config.max_brightness

    # Test range clipping
    Config.max_brightness = 300
    assert_equal 255, Config.max_brightness, "Max brightness should be clamped to 255"

    Config.max_brightness = -10
    assert_equal 0, Config.max_brightness, "Max brightness should be clamped to 0"
  end

  def test_max_lightness_accessor
    assert_equal 255, Config.max_lightness

    Config.max_lightness = 128
    assert_equal 128, Config.max_lightness

    # Test range clipping
    Config.max_lightness = 300
    assert_equal 255, Config.max_lightness, "Max lightness should be clamped to 255"

    Config.max_lightness = -10
    assert_equal 0, Config.max_lightness, "Max lightness should be clamped to 0"
  end

  # DevTool interface tests
  def test_mutable_keys_defined
    assert Config::MUTABLE_KEYS.is_a?(Hash)
    assert Config::MUTABLE_KEYS.key?('sensitivity')
    assert Config::MUTABLE_KEYS.key?('max_brightness')
    assert Config::MUTABLE_KEYS.key?('max_lightness')
  end

  def test_set_by_key_sensitivity
    result = Config.set_by_key('sensitivity', 2.5)
    assert_equal 2.5, Config.sensitivity
    assert_match(/sensitivity/, result)
  end

  def test_set_by_key_clamps_to_range
    Config.set_by_key('sensitivity', 999.0)
    assert_equal 10.0, Config.sensitivity

    Config.set_by_key('sensitivity', -5.0)
    assert_equal 0.05, Config.sensitivity
  end

  def test_set_by_key_max_brightness
    Config.set_by_key('max_brightness', 128)
    assert_equal 128, Config.max_brightness
  end

  def test_set_by_key_unknown_key
    result = Config.set_by_key('nonexistent', 42)
    assert_match(/Unknown key/, result)
  end

  def test_get_by_key
    Config.sensitivity = 2.0
    assert_equal 2.0, Config.get_by_key('sensitivity')
  end

  def test_get_by_key_unknown
    result = Config.get_by_key('nonexistent')
    assert_match(/Unknown key/, result)
  end

  def test_list_keys_returns_string
    result = Config.list_keys
    assert_instance_of String, result
    assert_match(/sensitivity/, result)
    assert_match(/max_brightness/, result)
    assert_match(/max_lightness/, result)
  end

  def test_reset_runtime
    Config.sensitivity = 5.0
    Config.max_brightness = 100
    Config.max_lightness = 100
    Config.reset_runtime
    assert_equal 1.0, Config.sensitivity
    assert_equal 255, Config.max_brightness
    assert_equal 255, Config.max_lightness
  end
end
