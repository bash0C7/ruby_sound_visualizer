require_relative 'test_helper'

class TestVRMMaterialController < Test::Unit::TestCase
  def setup
    JS.reset_global!
    @controller = VRMMaterialController.new
  end

  # --- Structure tests ---

  def test_has_default_base_emissive_intensity
    assert_kind_of Numeric, VRMMaterialController::DEFAULT_BASE_EMISSIVE_INTENSITY
    assert_operator VRMMaterialController::DEFAULT_BASE_EMISSIVE_INTENSITY, :>, 0.0
    assert_operator VRMMaterialController::DEFAULT_BASE_EMISSIVE_INTENSITY, :<, 5.0
  end

  def test_has_max_emissive_intensity
    assert_kind_of Numeric, VRMMaterialController::MAX_EMISSIVE_INTENSITY
    assert_operator VRMMaterialController::MAX_EMISSIVE_INTENSITY, :>, VRMMaterialController::DEFAULT_BASE_EMISSIVE_INTENSITY
  end

  # --- calculate_emissive_intensity() tests ---

  def test_calculate_emissive_intensity_accepts_energy_parameter
    # Should accept overall_energy (0.0-1.0) and return emissive intensity
    intensity = @controller.calculate_emissive_intensity(0.5)
    assert_kind_of Numeric, intensity
  end

  def test_calculate_emissive_intensity_at_zero_energy
    intensity = @controller.calculate_emissive_intensity(0.0)
    # At zero energy, should return base intensity
    assert_in_delta VRMMaterialController::DEFAULT_BASE_EMISSIVE_INTENSITY, intensity, 0.01
  end

  def test_calculate_emissive_intensity_at_max_energy
    intensity = @controller.calculate_emissive_intensity(1.0)
    # At max energy, should return max intensity
    assert_in_delta VRMMaterialController::MAX_EMISSIVE_INTENSITY, intensity, 0.01
  end

  def test_calculate_emissive_intensity_increases_with_energy
    intensity_low = @controller.calculate_emissive_intensity(0.2)
    intensity_mid = @controller.calculate_emissive_intensity(0.5)
    intensity_high = @controller.calculate_emissive_intensity(0.8)

    assert_operator intensity_mid, :>, intensity_low,
      "Intensity should increase with energy"
    assert_operator intensity_high, :>, intensity_mid,
      "Intensity should increase with energy"
  end

  def test_calculate_emissive_intensity_clamps_negative_energy
    intensity = @controller.calculate_emissive_intensity(-0.5)
    # Should clamp to base intensity
    assert_in_delta VRMMaterialController::DEFAULT_BASE_EMISSIVE_INTENSITY, intensity, 0.01
  end

  def test_calculate_emissive_intensity_clamps_over_max_energy
    intensity = @controller.calculate_emissive_intensity(2.0)
    # Should clamp to max intensity
    assert_in_delta VRMMaterialController::MAX_EMISSIVE_INTENSITY, intensity, 0.01
  end

  # --- apply_emissive() tests ---

  def test_apply_emissive_returns_material_config
    # This will be called from JS side, so it should return a config hash
    config = @controller.apply_emissive(1.5)
    assert_kind_of Hash, config
  end

  def test_apply_emissive_config_has_required_keys
    config = @controller.apply_emissive(1.5)
    assert_includes config.keys, :intensity
    assert_includes config.keys, :color
  end

  def test_apply_emissive_intensity_is_numeric
    config = @controller.apply_emissive(1.5)
    assert_kind_of Numeric, config[:intensity]
  end

  def test_apply_emissive_color_is_array_of_three_numbers
    config = @controller.apply_emissive(1.5)
    assert_kind_of Array, config[:color]
    assert_equal 3, config[:color].length
    config[:color].each do |val|
      assert_kind_of Numeric, val
      assert_operator val, :>=, 0.0
      assert_operator val, :<=, 1.0
    end
  end

  def test_apply_emissive_intensity_follows_energy
    config_low = @controller.apply_emissive(0.3)
    config_high = @controller.apply_emissive(0.9)

    assert_operator config_high[:intensity], :>, config_low[:intensity],
      "Higher energy should produce higher emissive intensity"
  end

  # --- Integration: multiple frames ---

  def test_multiple_frames_produce_valid_configs
    100.times do |i|
      energy = (Math.sin(i * 0.1) + 1.0) * 0.5  # 0.0-1.0
      config = @controller.apply_emissive(energy)

      assert_kind_of Hash, config, "Frame #{i}: config is not a Hash"
      assert_kind_of Numeric, config[:intensity], "Frame #{i}: intensity is not Numeric"
      assert_kind_of Array, config[:color], "Frame #{i}: color is not Array"
    end
  end
end
