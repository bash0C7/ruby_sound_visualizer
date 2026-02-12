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
    assert_match(/\bB:/, result)  # Word boundary to avoid matching "dB:"
    assert_match(/\bM:/, result)
    assert_match(/\bH:/, result)
    assert_match(/\bO:/, result)  # Overall
  end

  def test_format_debug_text_contains_hsv
    formatter = DebugFormatter.new
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    result = formatter.format_debug_text(analysis, {}, bpm: 0)
    assert_match(/HSV:/, result)  # Test for combined HSV: prefix
    assert_match(%r{HSV: \d+(\.\d+)?/\d+(\.\d+)?%/\d+(\.\d+)?%}, result)  # Test slash-separated format (decimals optional)
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

  def test_format_param_text_contains_mic_status
    formatter = DebugFormatter.new
    JS.set_global('micMuted', false)
    result = formatter.format_param_text
    assert_match(/MIC:ON/, result)
  end

  def test_format_param_text_mic_muted
    formatter = DebugFormatter.new
    JS.set_global('micMuted', true)
    result = formatter.format_param_text
    assert_match(/MIC:OFF/, result)
  end

  def test_format_param_text_contains_tab_status
    formatter = DebugFormatter.new
    result = formatter.format_param_text
    assert_match(/TAB:OFF/, result)
  end

  def test_format_param_text_tab_active
    formatter = DebugFormatter.new
    JS.set_global('tabStream', 'active')
    result = formatter.format_param_text
    assert_match(/TAB:ON/, result)
  end

  def test_format_key_guide_contains_mic_key
    formatter = DebugFormatter.new
    result = formatter.format_key_guide
    assert_match(/m: Mic/, result)
  end

  def test_format_key_guide_contains_tab_key
    formatter = DebugFormatter.new
    result = formatter.format_key_guide
    assert_match(/t: Tab/, result)
  end
end
