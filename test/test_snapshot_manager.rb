require_relative 'test_helper'
require_relative '../src/ruby/snapshot_manager'

class TestSnapshotManager < Test::Unit::TestCase
  def setup
    JS.reset_global!
    # Reset state to known defaults
    ColorPalette.set_hue_mode(nil)
    ColorPalette.set_hue_offset(0.0)
    VisualizerPolicy.max_brightness  = 255
    VisualizerPolicy.max_saturation  = 100
    VisualizerPolicy.sensitivity     = 1.0
    VisualizerPolicy.bloom_base_strength = 1.5
    VisualizerPolicy.max_bloom       = 4.5
    VisualizerPolicy.bloom_energy_scale  = 2.5
    VisualizerPolicy.bloom_impulse_scale = 1.5
    VisualizerPolicy.particle_explosion_base_prob   = 0.20
    VisualizerPolicy.particle_explosion_energy_scale = 0.50
    VisualizerPolicy.particle_explosion_force_scale  = 0.55
    VisualizerPolicy.particle_friction  = 0.86
    VisualizerPolicy.max_lightness   = 255
    VisualizerPolicy.max_emissive    = 2.0
    VisualizerPolicy.visual_smoothing = 0.70
    VisualizerPolicy.impulse_decay   = 0.82
  end

  # --- encode ---

  def test_encode_starts_with_schema_version
    result = SnapshotManager.encode({})
    assert_match(/\?v=1(&|$)/, result)
  end

  def test_encode_includes_all_known_keys
    result = SnapshotManager.encode({})
    %w[hue mode brt sat sens bbs bmax bes bis pp pes pfs fr ml me vs id cr cth cph].each do |key|
      assert_match(/[?&]#{key}=/, result, "missing key: #{key}")
    end
  end

  def test_encode_reflects_current_hue_offset
    ColorPalette.set_hue_offset(90.0)
    result = SnapshotManager.encode({})
    assert_match(/[?&]hue=90\.0/, result)
  end

  def test_encode_reflects_color_mode_1
    ColorPalette.set_hue_mode(1)
    result = SnapshotManager.encode({})
    assert_match(/[?&]mode=1/, result)
  end

  def test_encode_gray_mode_is_0
    ColorPalette.set_hue_mode(nil)
    result = SnapshotManager.encode({})
    assert_match(/[?&]mode=0/, result)
  end

  def test_encode_camera_defaults
    result = SnapshotManager.encode({})
    assert_match(/[?&]cr=5\.0/, result)
    assert_match(/[?&]cth=0/, result)
    assert_match(/[?&]cph=0/, result)
  end

  def test_encode_camera_with_values
    result = SnapshotManager.encode({ 'cr' => 10.0, 'cth' => 45.0, 'cph' => -20.0 })
    assert_match(/[?&]cr=10\.0/, result)
    assert_match(/[?&]cth=45/, result)
    assert_match(/[?&]cph=-20/, result)
  end

  def test_encode_returns_query_string_format
    result = SnapshotManager.encode({})
    assert result.start_with?('?'), "should start with ?"
    assert result.include?('&'), "should contain & separators"
  end

  # --- apply ---

  def test_apply_returns_empty_hash_when_no_v_key
    result = SnapshotManager.apply("")
    assert_equal({}, result)
  end

  def test_apply_returns_empty_hash_for_unrelated_params
    result = SnapshotManager.apply("?foo=1&bar=2")
    assert_equal({}, result)
  end

  def test_apply_requires_v_key_to_activate
    result = SnapshotManager.apply("?hue=90")
    assert_equal({}, result)
  end

  def test_apply_sets_hue_offset
    ColorPalette.set_hue_offset(0.0)
    SnapshotManager.apply("?v=1&hue=90")
    assert_in_delta 90.0, ColorPalette.get_hue_offset, 0.001
  end

  def test_apply_sets_color_mode_1
    SnapshotManager.apply("?v=1&mode=1")
    assert_equal 1, ColorPalette.get_hue_mode
  end

  def test_apply_sets_color_mode_0_as_nil
    ColorPalette.set_hue_mode(1)
    SnapshotManager.apply("?v=1&mode=0")
    assert_nil ColorPalette.get_hue_mode
  end

  def test_apply_sets_sensitivity
    SnapshotManager.apply("?v=1&sens=1.5")
    assert_in_delta 1.5, VisualizerPolicy.sensitivity, 0.001
  end

  def test_apply_sets_max_brightness
    SnapshotManager.apply("?v=1&brt=200")
    assert_equal 200, VisualizerPolicy.max_brightness
  end

  def test_apply_sets_max_saturation
    SnapshotManager.apply("?v=1&sat=50")
    assert_equal 50, VisualizerPolicy.max_saturation
  end

  def test_apply_returns_camera_values
    result = SnapshotManager.apply("?v=1&cr=10&cth=45&cph=20")
    assert_in_delta 10.0, result['cr'],  0.001
    assert_in_delta 45.0, result['cth'], 0.001
    assert_in_delta 20.0, result['cph'], 0.001
  end

  def test_apply_camera_defaults_when_missing
    result = SnapshotManager.apply("?v=1&hue=90")
    assert_in_delta 5.0, result['cr'],  0.001
    assert_in_delta 0.0, result['cth'], 0.001
    assert_in_delta 0.0, result['cph'], 0.001
  end

  def test_apply_unknown_keys_are_ignored
    # Should not raise, should just apply known keys
    result = SnapshotManager.apply("?v=2&newparam=99&hue=30")
    assert_in_delta 30.0, ColorPalette.get_hue_offset, 0.001
    assert result.is_a?(Hash)
  end

  def test_apply_missing_keys_leave_defaults_unchanged
    VisualizerPolicy.sensitivity = 1.5
    SnapshotManager.apply("?v=1&hue=90")
    # sensitivity not in URL → stays 1.5
    assert_in_delta 1.5, VisualizerPolicy.sensitivity, 0.001
  end

  def test_apply_sets_bloom_base_strength
    SnapshotManager.apply("?v=1&bbs=3.0")
    assert_in_delta 3.0, VisualizerPolicy.bloom_base_strength, 0.001
  end

  def test_apply_sets_particle_friction
    SnapshotManager.apply("?v=1&fr=0.90")
    assert_in_delta 0.90, VisualizerPolicy.particle_friction, 0.001
  end

  # --- register_callbacks ---

  def test_register_callbacks_sets_ruby_snapshot_encode
    SnapshotManager.register_callbacks
    assert_not_nil JS.global[:rubySnapshotEncode]
  end

  def test_register_callbacks_sets_ruby_snapshot_apply
    SnapshotManager.register_callbacks
    assert_not_nil JS.global[:rubySnapshotApply]
  end

  def test_ruby_snapshot_encode_callback_returns_query_string
    SnapshotManager.register_callbacks
    cb = JS.global[:rubySnapshotEncode]
    result = cb.call(5.0, 0, 0)
    assert result.to_s.start_with?('?')
  end

  def test_ruby_snapshot_apply_callback_returns_empty_for_no_v
    SnapshotManager.register_callbacks
    cb = JS.global[:rubySnapshotApply]
    result = cb.call("?foo=1")
    assert_equal "", result.to_s
  end

  def test_ruby_snapshot_apply_callback_returns_json_for_valid_snapshot
    SnapshotManager.register_callbacks
    cb = JS.global[:rubySnapshotApply]
    result = cb.call("?v=1&cr=10&cth=45&cph=20")
    json = result.to_s
    assert json.include?("cr"), "should contain cr: #{json}"
    assert json.include?("cth"), "should contain cth: #{json}"
    assert json.include?("cph"), "should contain cph: #{json}"
  end
end
