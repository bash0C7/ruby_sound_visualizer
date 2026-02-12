# Formats debug and parameter information for on-screen display.
# Extracted from main.rb to isolate display formatting concerns.
class DebugFormatter
  def initialize(audio_input_manager = nil)
    @audio_input_manager = audio_input_manager
  end

  def format_debug_text(analysis, beat, bpm: 0)
    energy = analysis[:overall_energy]
    volume_db = energy > 0.001 ? (20.0 * Math.log10(energy)).round(1) : -60.0

    hsv = ColorPalette.get_last_hsv
    hue_mode_val = ColorPalette.get_hue_mode
    mode_str = build_mode_string(hue_mode_val)

    bass_str = (analysis[:bass] * 100).round(1).to_s
    mid_str = (analysis[:mid] * 100).round(1).to_s
    high_str = (analysis[:high] * 100).round(1).to_s
    overall_str = (analysis[:overall_energy] * 100).round(1).to_s
    h_str = (hsv[0] * 360).round(1).to_s
    s_str = (hsv[1] * 100).round(1).to_s
    b_str = (hsv[2] * 100).round(1).to_s
    bpm_str = bpm > 0 ? "#{bpm} BPM" : "---"

    beat_now = []
    beat_now << "B" if beat[:bass]
    beat_now << "M" if beat[:mid]
    beat_now << "H" if beat[:high]
    beat_indicator = beat_now.empty? ? "" : " [#{beat_now.join("+")}]"

    "Mode: #{mode_str}  |  B: #{bass_str}%  M: #{mid_str}%  H: #{high_str}%  O: #{overall_str}%  Vol: #{volume_db.round(1)}dB  |  HSV: #{h_str}/#{s_str}%/#{b_str}%  |  #{bpm_str}#{beat_indicator}"
  end

  def format_param_text
    if @audio_input_manager
      # Use AudioInputManager for state management
      mic_status = @audio_input_manager.mic_muted? ? "MIC:OFF" : "MIC:ON"
      tab_status = @audio_input_manager.tab_capture? ? "TAB:ON" : "TAB:OFF"
    else
      # Fallback to JS.global for backward compatibility
      mic_status = JS.global[:micMuted] == true ? "MIC:OFF" : "MIC:ON"
      tab_val = JS.global[:tabStream]
      tab_active = tab_val.respond_to?(:typeof) ? (tab_val.typeof.to_s != "undefined" && tab_val.typeof.to_s != "null") : !!tab_val
      tab_status = tab_active ? "TAB:ON" : "TAB:OFF"
    end
    "#{mic_status}  #{tab_status}  |  Sensitivity: #{VisualizerPolicy.sensitivity.round(2)}x  |  MaxBrightness: #{VisualizerPolicy.max_brightness}  |  MaxLightness: #{VisualizerPolicy.max_lightness}"
  end

  def format_key_guide
    "m: Mic mute  |  t: Tab capture  |  0-3: Color Mode  |  4/5: Hue Shift  |  6/7: Brightness ±5  |  8/9: Lightness ±5  |  +/-: Sensitivity  |  a/s: Cam X  |  w/x: Cam Y  |  q/z: Cam Z"
  end

  private

  def build_mode_string(hue_mode_val)
    base = hue_mode_val.nil? ? "0:Gray" : "#{hue_mode_val}:Hue"
    hue_offset_val = ColorPalette.get_hue_offset
    hue_offset_val == 0.0 ? base : "#{base}+#{hue_offset_val.round(0)}deg"
  end
end
