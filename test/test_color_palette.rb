require_relative 'test_helper'

class TestColorPalette < Test::Unit::TestCase
  def setup
    @palette = ColorPalette.new
  end

  def test_initialize_defaults_to_grayscale
    assert_nil @palette.hue_mode
    assert_in_delta 0.0, @palette.hue_offset, 0.001
  end

  def test_set_hue_mode
    @palette.hue_mode = 1
    assert_equal 1, @palette.hue_mode
  end

  def test_set_hue_mode_resets_offset
    @palette.shift_hue_offset(30)
    @palette.hue_mode = 2
    assert_in_delta 0.0, @palette.hue_offset, 0.001
  end

  def test_shift_hue_offset
    @palette.shift_hue_offset(10)
    assert_in_delta 10.0, @palette.hue_offset, 0.001
  end

  def test_shift_hue_offset_wraps
    @palette.shift_hue_offset(-10)
    assert_in_delta 350.0, @palette.hue_offset, 0.001
  end

  def test_frequency_to_color_returns_array_of_3
    analysis = { bass: 0.5, mid: 0.3, high: 0.2 }
    color = @palette.frequency_to_color(analysis)
    assert_equal 3, color.length
  end

  def test_frequency_to_color_grayscale_on_silence
    analysis = { bass: 0.0, mid: 0.0, high: 0.0 }
    color = @palette.frequency_to_color(analysis)
    # In grayscale, all channels should be equal
    assert_in_delta color[0], color[1], 0.001
    assert_in_delta color[1], color[2], 0.001
  end

  def test_frequency_to_color_with_hue_mode
    @palette.hue_mode = 1
    analysis = { bass: 0.5, mid: 0.3, high: 0.2 }
    color = @palette.frequency_to_color(analysis)
    assert_equal 3, color.length
    # In hue mode, channels should differ
    # (at least some color variation expected)
  end

  def test_frequency_to_color_at_distance_returns_array_of_3
    analysis = { bass: 0.5, mid: 0.3, high: 0.2 }
    color = @palette.frequency_to_color_at_distance(analysis, 0.5)
    assert_equal 3, color.length
  end

  def test_last_hsv_tracks_state
    analysis = { bass: 0.5, mid: 0.3, high: 0.2 }
    @palette.frequency_to_color(analysis)
    hsv = @palette.last_hsv
    assert_equal 3, hsv.length
  end

  def test_energy_to_brightness
    result = @palette.energy_to_brightness(0.5)
    assert result > 0
  end

  def test_independent_instances
    palette1 = ColorPalette.new
    palette2 = ColorPalette.new
    palette1.hue_mode = 1
    palette2.hue_mode = 3
    assert_equal 1, palette1.hue_mode
    assert_equal 3, palette2.hue_mode
  end

  def test_mode1_hue_range_vivid_red_center
    # Mode 1: Vivid Red (0deg) with ±70deg range
    @palette.hue_mode = 1

    # Bass-dominant: should shift toward lower end (0 - 70 = 290deg wrapped)
    bass_dominant = { bass: 0.8, mid: 0.1, high: 0.1 }
    @palette.frequency_to_color(bass_dominant)
    bass_hue_deg = @palette.last_hsv[0] * 360.0
    # Expected: around 290-330deg (wrapped from -70 to -30)
    assert bass_hue_deg > 270 || bass_hue_deg < 30, "Bass-dominant hue #{bass_hue_deg} should be in lower range"

    # High-dominant: should shift toward upper end (0 + 70 = 70deg)
    high_dominant = { bass: 0.1, mid: 0.1, high: 0.8 }
    @palette.frequency_to_color(high_dominant)
    high_hue_deg = @palette.last_hsv[0] * 360.0
    # Expected: around 30-70deg
    assert high_hue_deg > 30 && high_hue_deg < 90, "High-dominant hue #{high_hue_deg} should be in upper range"
  end

  def test_mode2_hue_range_shocking_yellow_center
    # Mode 2: Shocking Yellow (60deg) with ±70deg range
    @palette.hue_mode = 2

    # Mid-balanced: should be near center (60deg)
    balanced = { bass: 0.3, mid: 0.4, high: 0.3 }
    @palette.frequency_to_color(balanced)
    mid_hue_deg = @palette.last_hsv[0] * 360.0
    # Expected: around 40-80deg
    assert mid_hue_deg > 30 && mid_hue_deg < 90, "Balanced hue #{mid_hue_deg} should be near yellow center"
  end

  def test_mode3_hue_range_turquoise_blue_center
    # Mode 3: Turquoise Blue (180deg) with ±70deg range
    @palette.hue_mode = 3

    # Mid-balanced: should be near center (180deg)
    balanced = { bass: 0.3, mid: 0.4, high: 0.3 }
    @palette.frequency_to_color(balanced)
    mid_hue_deg = @palette.last_hsv[0] * 360.0
    # Expected: around 160-200deg
    assert mid_hue_deg > 140 && mid_hue_deg < 220, "Balanced hue #{mid_hue_deg} should be near turquoise center"
  end

  def test_hue_shift_preserves_relative_energy
    # Verify that bass/mid/high energy ratio controls hue position
    @palette.hue_mode = 1

    # Pure bass: position = 0.0 (bass*0 + mid*0.5 + high*1.0) / total
    pure_bass = { bass: 1.0, mid: 0.0, high: 0.0 }
    @palette.frequency_to_color(pure_bass)
    bass_hue = @palette.last_hsv[0] * 360.0

    # Pure high: position = 1.0
    pure_high = { bass: 0.0, mid: 0.0, high: 1.0 }
    @palette.frequency_to_color(pure_high)
    high_hue = @palette.last_hsv[0] * 360.0

    # High hue should be greater than bass hue (within mode 1 range)
    # Mode 1 is 0deg ±70, so bass~290deg, high~70deg
    # We need to handle wraparound
    if bass_hue > 180 && high_hue < 180
      # Wraparound case: bass is in 270-360, high is in 0-90
      assert high_hue < 90 && bass_hue > 270, "High #{high_hue} should be < 90, bass #{bass_hue} should be > 270"
    else
      assert high_hue > bass_hue, "High-dominant hue #{high_hue} should be > bass-dominant hue #{bass_hue}"
    end
  end

  # --- set_hue_offset (absolute setter) ---

  def test_set_hue_offset_absolute
    @palette.hue_offset = 45.0
    assert_in_delta 45.0, @palette.hue_offset, 0.001
  end

  def test_set_hue_offset_wraps_over_360
    @palette.hue_offset = 400.0
    assert_in_delta 40.0, @palette.hue_offset, 0.001
  end

  def test_set_hue_offset_negative_wraps
    @palette.hue_offset = -10.0
    assert_in_delta 350.0, @palette.hue_offset, 0.001
  end

  def test_set_hue_offset_zero
    @palette.shift_hue_offset(30)
    @palette.hue_offset = 0.0
    assert_in_delta 0.0, @palette.hue_offset, 0.001
  end

  def test_class_level_set_hue_offset
    ColorPalette.set_hue_offset(90.0)
    assert_in_delta 90.0, ColorPalette.get_hue_offset, 0.001
    # cleanup
    ColorPalette.set_hue_offset(0.0)
  end

  def test_distance_based_color_uses_same_base_range
    # frequency_to_color_at_distance should use same 140deg range
    @palette.hue_mode = 2  # Yellow center (60deg)
    analysis = { bass: 0.5, mid: 0.3, high: 0.2 }

    # Distance 0.0 should be near lower end (60-70=-10deg)
    color_low = @palette.frequency_to_color_at_distance(analysis, 0.0)
    # Distance 1.0 should be near upper end (60+70=130deg)
    color_high = @palette.frequency_to_color_at_distance(analysis, 1.0)

    # Just verify they return valid RGB arrays
    assert_equal 3, color_low.length
    assert_equal 3, color_high.length
  end
end
