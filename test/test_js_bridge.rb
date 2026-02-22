require_relative 'test_helper'

class TestJSBridge < Test::Unit::TestCase
  def setup
    JS.reset_global!
    @calls = []
    # Track JS.global method calls
    mock = JS.global
    def mock.updateParticles(*args); end
    def mock.updateGeometry(*args); end
    def mock.updateBloom(*args); end
    def mock.updateCamera(*args); end
    def mock.updateParticleRotation(*args); end
    def mock.updateVRM(*args); end
    def mock.updateVRMMaterial(*args); end
  end

  # -- update_particles --

  def test_update_particles_with_valid_data
    data = { positions: [1.0, 2.0, 3.0], colors: [0.5, 0.5, 0.5], avg_size: 0.1, avg_opacity: 0.9 }
    assert_nothing_raised { JSBridge.update_particles(data) }
  end

  def test_update_particles_skips_when_positions_not_array
    data = { positions: nil, colors: [0.5], avg_size: 0.1, avg_opacity: 0.9 }
    assert_nothing_raised { JSBridge.update_particles(data) }
  end

  def test_update_particles_skips_when_colors_not_array
    data = { positions: [1.0], colors: nil, avg_size: 0.1, avg_opacity: 0.9 }
    assert_nothing_raised { JSBridge.update_particles(data) }
  end

  def test_update_particles_uses_default_avg_size
    data = { positions: [1.0], colors: [0.5] }
    assert_nothing_raised { JSBridge.update_particles(data) }
  end

  # -- update_geometry --

  def test_update_geometry_with_valid_data
    data = { scale: 1.5, rotation: [0.1, 0.2, 0.3], emissive_intensity: 1.0, color: [1.0, 0.0, 0.0] }
    assert_nothing_raised { JSBridge.update_geometry(data) }
  end

  def test_update_geometry_skips_when_rotation_not_array
    data = { scale: 1.5, rotation: nil, emissive_intensity: 1.0 }
    assert_nothing_raised { JSBridge.update_geometry(data) }
  end

  def test_update_geometry_uses_default_color
    data = { scale: 1.5, rotation: [0.1, 0.2, 0.3], emissive_intensity: 1.0 }
    assert_nothing_raised { JSBridge.update_geometry(data) }
  end

  # -- update_bloom --

  def test_update_bloom_with_valid_data
    data = { strength: 2.0, threshold: 0.1 }
    assert_nothing_raised { JSBridge.update_bloom(data) }
  end

  # -- update_camera --

  def test_update_camera_with_valid_data
    data = { position: [0, 0, 5], shake: [0.01, -0.01, 0.005] }
    assert_nothing_raised { JSBridge.update_camera(data) }
  end

  def test_update_camera_skips_when_position_not_array
    data = { position: nil, shake: [0.01] }
    assert_nothing_raised { JSBridge.update_camera(data) }
  end

  def test_update_camera_skips_when_shake_not_array
    data = { position: [0, 0, 5], shake: nil }
    assert_nothing_raised { JSBridge.update_camera(data) }
  end

  # -- update_particle_rotation --

  def test_update_particle_rotation_with_valid_data
    assert_nothing_raised { JSBridge.update_particle_rotation([0.1, 0.2, 0.3]) }
  end

  def test_update_particle_rotation_applies_half_speed
    called_with = nil
    mock = JS.global
    mock.define_singleton_method(:updateParticleRotation) { |rot| called_with = rot }
    JSBridge.update_particle_rotation([0.4, 0.6, 0.8])
    assert_equal [0.2, 0.3, 0.4], called_with
  end

  def test_update_particle_rotation_skips_short_array
    assert_nothing_raised { JSBridge.update_particle_rotation([0.1, 0.2]) }
  end

  def test_update_particle_rotation_skips_non_array
    assert_nothing_raised { JSBridge.update_particle_rotation(nil) }
  end

  # -- update_vrm --

  def test_update_vrm_with_valid_data
    data = { rotations: Array.new(42, 0.0), hips_position_y: 0.0, blink: 0.0, mouth_open_vertical: 0.0, mouth_open_horizontal: 0.0 }
    assert_nothing_raised { JSBridge.update_vrm(data) }
  end

  def test_update_vrm_skips_when_rotations_not_array
    data = { rotations: nil }
    assert_nothing_raised { JSBridge.update_vrm(data) }
  end

  def test_update_vrm_uses_defaults_for_optional_keys
    data = { rotations: [0.1, 0.2, 0.3] }
    assert_nothing_raised { JSBridge.update_vrm(data) }
  end

  # -- update_vrm_material --

  def test_update_vrm_material_with_valid_data
    config = { intensity: 1.5, color: [1.0, 0.5, 0.0] }
    assert_nothing_raised { JSBridge.update_vrm_material(config) }
  end

  def test_update_vrm_material_uses_defaults
    config = {}
    assert_nothing_raised { JSBridge.update_vrm_material(config) }
  end

  # -- update_synth --

  def test_update_synth_with_valid_data
    data = {
      frequency: 440, duty: 50, active: true, gain: 0.3,
      waveform: :sawtooth, attack: 0.01, decay: 0.3, sustain: 0.6, release: 0.3,
      filter_cutoff: 2000.0, filter_resonance: 1.0, filter_type: :lowpass
    }
    assert_nothing_raised { JSBridge.update_synth(data) }
  end

  def test_update_synth_inactive
    data = {
      frequency: 0, duty: 0, active: false, gain: 0.3,
      waveform: :sawtooth, attack: 0.01, decay: 0.3, sustain: 0.6, release: 0.3,
      filter_cutoff: 2000.0, filter_resonance: 1.0, filter_type: :lowpass
    }
    assert_nothing_raised { JSBridge.update_synth(data) }
  end

  # -- update_oscilloscope --

  def test_update_oscilloscope_with_valid_data
    data = {
      waveform: Array.new(256, 0.0), scroll_offset: 0.5,
      intensity: 0.8, color: [0.0, 1.0, 0.4],
      z_position: 8.0, y_position: -2.0, enabled: true
    }
    assert_nothing_raised { JSBridge.update_oscilloscope(data) }
  end

  def test_update_oscilloscope_skips_when_disabled
    data = {
      waveform: Array.new(256, 0.0), scroll_offset: 0.5,
      intensity: 0.8, color: [0.0, 1.0, 0.4],
      z_position: 8.0, y_position: -2.0, enabled: false
    }
    # Should not call JS when disabled
    assert_nothing_raised { JSBridge.update_oscilloscope(data) }
  end

  # -- log / error --

  def test_log_does_not_raise
    assert_nothing_raised { JSBridge.log("test message") }
  end

  def test_error_does_not_raise
    assert_nothing_raised { JSBridge.error("test error") }
  end
end
