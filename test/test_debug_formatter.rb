require_relative 'test_helper'

class TestDebugFormatter < Test::Unit::TestCase
  def setup
    JS.reset_global!
    ColorPalette.set_hue_mode(nil)
  end

  def test_format_debug_text_returns_string
    formatter = DebugFormatter.new
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    beat = {}
    result = formatter.format_debug_text(analysis, beat, bpm: 0)
    assert_instance_of String, result
  end

  def test_format_debug_text_contains_mode
    formatter = DebugFormatter.new
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    result = formatter.format_debug_text(analysis, {}, bpm: 0)
    assert_match(/Mode:/, result)
  end

  def test_format_debug_text_contains_frequencies
    formatter = DebugFormatter.new
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    result = formatter.format_debug_text(analysis, {}, bpm: 0)
    assert_match(/Bass:/, result)
    assert_match(/Mid:/, result)
    assert_match(/High:/, result)
  end

  def test_format_debug_text_contains_hsv
    formatter = DebugFormatter.new
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    result = formatter.format_debug_text(analysis, {}, bpm: 0)
    assert_match(/H:/, result)
    assert_match(/S:/, result)
    assert_match(/B:/, result)
  end

  def test_format_debug_text_shows_beat_indicator
    formatter = DebugFormatter.new
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    beat = { bass: true, mid: false, high: true }
    result = formatter.format_debug_text(analysis, beat, bpm: 120)
    assert_match(/\[B\+H\]/, result)
  end

  def test_format_debug_text_no_beat_indicator_when_silent
    formatter = DebugFormatter.new
    analysis = { bass: 0.0, mid: 0.0, high: 0.0, overall_energy: 0.0 }
    beat = {}
    result = formatter.format_debug_text(analysis, beat, bpm: 0)
    refute_match(/\[.*\]/, result)
  end

  def test_format_debug_text_shows_bpm
    formatter = DebugFormatter.new
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    result = formatter.format_debug_text(analysis, {}, bpm: 120)
    assert_match(/120 BPM/, result)
  end

  def test_format_debug_text_shows_dashes_when_no_bpm
    formatter = DebugFormatter.new
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    result = formatter.format_debug_text(analysis, {}, bpm: 0)
    assert_match(/---/, result)
  end

  def test_format_param_text_returns_string
    formatter = DebugFormatter.new
    result = formatter.format_param_text
    assert_instance_of String, result
  end

  def test_format_param_text_contains_sensitivity
    formatter = DebugFormatter.new
    result = formatter.format_param_text
    assert_match(/Sensitivity:/, result)
  end

  def test_format_param_text_contains_brightness
    formatter = DebugFormatter.new
    result = formatter.format_param_text
    assert_match(/MaxBrightness:/, result)
  end

  def test_format_param_text_contains_lightness
    formatter = DebugFormatter.new
    result = formatter.format_param_text
    assert_match(/MaxLightness:/, result)
  end

  def test_format_key_guide_returns_string
    formatter = DebugFormatter.new
    result = formatter.format_key_guide
    assert_instance_of String, result
  end

  def test_format_key_guide_contains_color_mode
    formatter = DebugFormatter.new
    result = formatter.format_key_guide
    assert_match(/0-3:/, result)
  end

  def test_format_debug_text_with_hue_mode
    formatter = DebugFormatter.new
    ColorPalette.set_hue_mode(1)
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    result = formatter.format_debug_text(analysis, {}, bpm: 0)
    assert_match(/1:Hue/, result)
  end

  def test_format_debug_text_with_hue_offset
    formatter = DebugFormatter.new
    ColorPalette.set_hue_mode(1)
    ColorPalette.shift_hue_offset(30)
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    result = formatter.format_debug_text(analysis, {}, bpm: 0)
    assert_match(/30deg/, result)
  end

  def test_format_debug_text_zero_energy_volume
    formatter = DebugFormatter.new
    analysis = { bass: 0.0, mid: 0.0, high: 0.0, overall_energy: 0.0 }
    result = formatter.format_debug_text(analysis, {}, bpm: 0)
    assert_match(/-60\.0dB/, result)
  end
end
