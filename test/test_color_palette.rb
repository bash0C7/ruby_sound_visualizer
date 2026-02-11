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
end
