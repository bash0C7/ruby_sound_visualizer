require_relative 'test_helper'

class TestKeyboardHandler < Test::Unit::TestCase
  def setup
    JS.reset_global!
    # Reset Config to defaults
    Config.sensitivity = 1.0
    Config.max_brightness = 255
    Config.max_lightness = 255
    # Reset ColorPalette state
    ColorPalette.set_hue_mode(nil)
  end

  def test_initialize_registers_callbacks
    handler = KeyboardHandler.new
    # After initialization, callbacks should be registered on JS.global
    assert_not_nil JS.global[:rubySetColorMode]
    assert_not_nil JS.global[:rubyAdjustSensitivity]
    assert_not_nil JS.global[:rubyShiftHue]
    assert_not_nil JS.global[:rubyAdjustMaxBrightness]
    assert_not_nil JS.global[:rubyAdjustMaxLightness]
  end

  def test_set_color_mode_grayscale
    handler = KeyboardHandler.new
    handler.handle_color_mode(0)
    assert_nil ColorPalette.get_hue_mode
  end

  def test_set_color_mode_red
    handler = KeyboardHandler.new
    handler.handle_color_mode(1)
    assert_equal 1, ColorPalette.get_hue_mode
  end

  def test_set_color_mode_green
    handler = KeyboardHandler.new
    handler.handle_color_mode(2)
    assert_equal 2, ColorPalette.get_hue_mode
  end

  def test_set_color_mode_blue
    handler = KeyboardHandler.new
    handler.handle_color_mode(3)
    assert_equal 3, ColorPalette.get_hue_mode
  end

  def test_adjust_sensitivity_increase
    handler = KeyboardHandler.new
    handler.handle_sensitivity(0.05)
    assert_in_delta 1.05, Config.sensitivity, 0.001
  end

  def test_adjust_sensitivity_decrease
    handler = KeyboardHandler.new
    handler.handle_sensitivity(-0.05)
    assert_in_delta 0.95, Config.sensitivity, 0.001
  end

  def test_adjust_sensitivity_minimum_clamp
    handler = KeyboardHandler.new
    Config.sensitivity = 0.05
    handler.handle_sensitivity(-0.10)
    assert_in_delta 0.05, Config.sensitivity, 0.001
  end

  def test_shift_hue_positive
    handler = KeyboardHandler.new
    handler.handle_hue_shift(5)
    assert_in_delta 5.0, ColorPalette.get_hue_offset, 0.001
  end

  def test_shift_hue_negative
    handler = KeyboardHandler.new
    handler.handle_hue_shift(-5)
    assert_in_delta 355.0, ColorPalette.get_hue_offset, 0.001
  end

  def test_adjust_max_brightness_increase
    handler = KeyboardHandler.new
    Config.max_brightness = 200
    handler.handle_brightness(5)
    assert_equal 205, Config.max_brightness
  end

  def test_adjust_max_brightness_decrease
    handler = KeyboardHandler.new
    Config.max_brightness = 200
    handler.handle_brightness(-5)
    assert_equal 195, Config.max_brightness
  end

  def test_adjust_max_brightness_clamp_upper
    handler = KeyboardHandler.new
    Config.max_brightness = 253
    handler.handle_brightness(5)
    assert_equal 255, Config.max_brightness
  end

  def test_adjust_max_brightness_clamp_lower
    handler = KeyboardHandler.new
    Config.max_brightness = 3
    handler.handle_brightness(-5)
    assert_equal 0, Config.max_brightness
  end

  def test_adjust_max_lightness_increase
    handler = KeyboardHandler.new
    Config.max_lightness = 200
    handler.handle_lightness(5)
    assert_equal 205, Config.max_lightness
  end

  def test_adjust_max_lightness_clamp_upper
    handler = KeyboardHandler.new
    Config.max_lightness = 253
    handler.handle_lightness(5)
    assert_equal 255, Config.max_lightness
  end

  # Master dispatch tests (rubyHandleKey)
  def test_master_dispatch_registers_callback
    handler = KeyboardHandler.new
    assert_not_nil JS.global[:rubyHandleKey]
  end

  def test_dispatch_color_mode_0
    handler = KeyboardHandler.new
    ColorPalette.set_hue_mode(1)
    handler.handle_key('0')
    assert_nil ColorPalette.get_hue_mode
  end

  def test_dispatch_color_mode_1
    handler = KeyboardHandler.new
    handler.handle_key('1')
    assert_equal 1, ColorPalette.get_hue_mode
  end

  def test_dispatch_hue_shift_4
    handler = KeyboardHandler.new
    handler.handle_key('4')
    assert_in_delta 355.0, ColorPalette.get_hue_offset, 0.001
  end

  def test_dispatch_hue_shift_5
    handler = KeyboardHandler.new
    handler.handle_key('5')
    assert_in_delta 5.0, ColorPalette.get_hue_offset, 0.001
  end

  def test_dispatch_brightness_6
    handler = KeyboardHandler.new
    handler.handle_key('6')
    assert_equal 250, Config.max_brightness
  end

  def test_dispatch_brightness_7
    handler = KeyboardHandler.new
    Config.max_brightness = 200
    handler.handle_key('7')
    assert_equal 205, Config.max_brightness
  end

  def test_dispatch_lightness_8
    handler = KeyboardHandler.new
    handler.handle_key('8')
    assert_equal 250, Config.max_lightness
  end

  def test_dispatch_sensitivity_minus
    handler = KeyboardHandler.new
    handler.handle_key('-')
    assert_in_delta 0.95, Config.sensitivity, 0.001
  end

  def test_dispatch_sensitivity_plus
    handler = KeyboardHandler.new
    handler.handle_key('+')
    assert_in_delta 1.05, Config.sensitivity, 0.001
  end

  def test_dispatch_sensitivity_equals
    handler = KeyboardHandler.new
    handler.handle_key('=')
    assert_in_delta 1.05, Config.sensitivity, 0.001
  end

  def test_dispatch_unknown_key_does_nothing
    handler = KeyboardHandler.new
    # Should not raise
    handler.handle_key('`')
  end
end
