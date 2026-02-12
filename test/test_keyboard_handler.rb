require_relative 'test_helper'

class TestKeyboardHandler < Test::Unit::TestCase
  def setup
    JS.reset_global!
    # Reset Config to defaults
    VisualizerPolicy.sensitivity = 1.0
    VisualizerPolicy.max_brightness = 255
    VisualizerPolicy.max_lightness = 255
    # Reset ColorPalette state
    ColorPalette.set_hue_mode(nil)
  end

  def test_initialize_registers_callbacks
    _handler = KeyboardHandler.new
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
    assert_in_delta 1.05, VisualizerPolicy.sensitivity, 0.001
  end

  def test_adjust_sensitivity_decrease
    handler = KeyboardHandler.new
    handler.handle_sensitivity(-0.05)
    assert_in_delta 0.95, VisualizerPolicy.sensitivity, 0.001
  end

  def test_adjust_sensitivity_minimum_clamp
    handler = KeyboardHandler.new
    VisualizerPolicy.sensitivity = 0.05
    handler.handle_sensitivity(-0.10)
    assert_in_delta 0.05, VisualizerPolicy.sensitivity, 0.001
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
    VisualizerPolicy.max_brightness = 200
    handler.handle_brightness(5)
    assert_equal 205, VisualizerPolicy.max_brightness
  end

  def test_adjust_max_brightness_decrease
    handler = KeyboardHandler.new
    VisualizerPolicy.max_brightness = 200
    handler.handle_brightness(-5)
    assert_equal 195, VisualizerPolicy.max_brightness
  end

  def test_adjust_max_brightness_clamp_upper
    handler = KeyboardHandler.new
    VisualizerPolicy.max_brightness = 253
    handler.handle_brightness(5)
    assert_equal 255, VisualizerPolicy.max_brightness
  end

  def test_adjust_max_brightness_clamp_lower
    handler = KeyboardHandler.new
    VisualizerPolicy.max_brightness = 3
    handler.handle_brightness(-5)
    assert_equal 0, VisualizerPolicy.max_brightness
  end

  def test_adjust_max_lightness_increase
    handler = KeyboardHandler.new
    VisualizerPolicy.max_lightness = 200
    handler.handle_lightness(5)
    assert_equal 205, VisualizerPolicy.max_lightness
  end

  def test_adjust_max_lightness_clamp_upper
    handler = KeyboardHandler.new
    VisualizerPolicy.max_lightness = 253
    handler.handle_lightness(5)
    assert_equal 255, VisualizerPolicy.max_lightness
  end

  # Master dispatch tests (rubyHandleKey)
  def test_master_dispatch_registers_callback
    _handler = KeyboardHandler.new
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
    assert_equal 250, VisualizerPolicy.max_brightness
  end

  def test_dispatch_brightness_7
    handler = KeyboardHandler.new
    VisualizerPolicy.max_brightness = 200
    handler.handle_key('7')
    assert_equal 205, VisualizerPolicy.max_brightness
  end

  def test_dispatch_lightness_8
    handler = KeyboardHandler.new
    handler.handle_key('8')
    assert_equal 250, VisualizerPolicy.max_lightness
  end

  def test_dispatch_sensitivity_minus
    handler = KeyboardHandler.new
    handler.handle_key('-')
    assert_in_delta 0.95, VisualizerPolicy.sensitivity, 0.001
  end

  def test_dispatch_sensitivity_plus
    handler = KeyboardHandler.new
    handler.handle_key('+')
    assert_in_delta 1.05, VisualizerPolicy.sensitivity, 0.001
  end

  def test_dispatch_sensitivity_equals
    handler = KeyboardHandler.new
    handler.handle_key('=')
    assert_in_delta 1.05, VisualizerPolicy.sensitivity, 0.001
  end

  def test_dispatch_unknown_key_does_nothing
    handler = KeyboardHandler.new
    # Should not raise
    handler.handle_key('`')
  end

  # === Mic toggle ('m' key) tests ===

  def test_m_key_toggles_mic_mute_state_via_audio_input_manager
    manager = AudioInputManager.new
    handler = KeyboardHandler.new(manager)

    # Initial state: unmuted
    assert_equal false, manager.mic_muted?

    # Press 'm' to mute
    handler.handle_key('m')
    assert_equal true, manager.mic_muted?

    # Press 'm' again to unmute
    handler.handle_key('m')
    assert_equal false, manager.mic_muted?
  end

  def test_multiple_m_key_presses_toggle_mic_state
    manager = AudioInputManager.new
    handler = KeyboardHandler.new(manager)

    # Toggle 5 times
    5.times { handler.handle_key('m') }
    assert_equal true, manager.mic_muted?

    # Toggle once more
    handler.handle_key('m')
    assert_equal false, manager.mic_muted?
  end

  # === Tab capture ('t' key) tests ===

  def test_t_key_switches_to_tab_capture_via_audio_input_manager
    manager = AudioInputManager.new
    handler = KeyboardHandler.new(manager)

    # Initial state: microphone
    assert_equal :microphone, manager.source

    # Press 't' to switch to tab
    handler.handle_key('t')
    assert_equal :tab, manager.source
  end

  # === Backward compatibility tests ===

  def test_keyboard_handler_without_audio_input_manager_still_works
    # KeyboardHandler should still work without audio_input_manager for backward compatibility
    handler = KeyboardHandler.new(nil)

    # Should not raise when handling color mode keys
    handler.handle_key('0')
    assert_nil ColorPalette.get_hue_mode
  end

  def test_m_key_without_audio_input_manager_does_nothing
    handler = KeyboardHandler.new(nil)

    # Should not raise, just silently do nothing
    handler.handle_key('m')
  end
end
