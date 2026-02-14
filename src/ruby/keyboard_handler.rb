# Handles all keyboard input callbacks from JavaScript.
# Master dispatch via rubyHandleKey + individual callbacks for backward compat.
class KeyboardHandler
  def initialize(audio_input_manager = nil)
    @audio_input_manager = audio_input_manager
    register_callbacks
    register_master_dispatch
  end

  # Master dispatch: called by JS with raw key string
  def handle_key(key)
    case key
    when '0' then handle_color_mode(0)
    when '1' then handle_color_mode(1)
    when '2' then handle_color_mode(2)
    when '3' then handle_color_mode(3)
    when '4' then handle_hue_shift(-5)
    when '5' then handle_hue_shift(5)
    when '6' then handle_brightness(-5)
    when '7' then handle_brightness(5)
    when '8' then handle_lightness(-5)
    when '9' then handle_lightness(5)
    when '-' then handle_sensitivity(-0.05)
    when '+', '=' then handle_sensitivity(0.05)
    when 'm' then handle_mic_toggle
    when 't' then handle_tab_capture
    end
  end

  def handle_color_mode(key)
    case key
    when 0
      ColorPalette.set_hue_mode(nil)
      VisualizerPolicy.max_saturation = 0
      JSBridge.log "Color Mode: Grayscale"
    when 1
      ColorPalette.set_hue_mode(1)
      VisualizerPolicy.max_saturation = 100 if VisualizerPolicy.max_saturation == 0
      JSBridge.log "Color Mode: 1:Vivid Red (±70deg)"
    when 2
      ColorPalette.set_hue_mode(2)
      VisualizerPolicy.max_saturation = 100 if VisualizerPolicy.max_saturation == 0
      JSBridge.log "Color Mode: 2:Shocking Yellow (±70deg)"
    when 3
      ColorPalette.set_hue_mode(3)
      VisualizerPolicy.max_saturation = 100 if VisualizerPolicy.max_saturation == 0
      JSBridge.log "Color Mode: 3:Turquoise Blue (±70deg)"
    end
  end

  def handle_sensitivity(delta)
    VisualizerPolicy.sensitivity = [(VisualizerPolicy.sensitivity + delta).round(2), 0.05].max
    JSBridge.log "Sensitivity: #{VisualizerPolicy.sensitivity}x"
  end

  def handle_hue_shift(delta)
    ColorPalette.shift_hue_offset(delta)
    offset = ColorPalette.get_hue_offset
    JSBridge.log "Hue Offset: #{offset.round(1)} deg"
  end

  def handle_brightness(delta)
    VisualizerPolicy.max_brightness = [[VisualizerPolicy.max_brightness + delta, 0].max, 255].min
    JSBridge.log "MaxBrightness: #{VisualizerPolicy.max_brightness}"
  end

  def handle_lightness(delta)
    VisualizerPolicy.max_lightness = [[VisualizerPolicy.max_lightness + delta, 0].max, 255].min
    JSBridge.log "MaxLightness: #{VisualizerPolicy.max_lightness}"
  end

  def handle_mic_toggle
    return unless @audio_input_manager

    @audio_input_manager.toggle_mic
    volume = @audio_input_manager.mic_volume
    JS.global.call(:setMicVolume, volume) if JS.global.respond_to?(:call)

    status = @audio_input_manager.mic_muted? ? "OFF" : "ON"
    JSBridge.log "Mic: #{status}"
  end

  def handle_tab_capture
    return unless @audio_input_manager

    @audio_input_manager.switch_to_tab
    JS.global.call(:captureTab, true) if JS.global.respond_to?(:call)

    status = @audio_input_manager.tab_capture? ? "ON" : "OFF"
    JSBridge.log "Tab Capture: #{status}"
  end

  private

  def register_master_dispatch
    handler = self
    JS.global[:rubyHandleKey] = lambda do |key|
      begin
        handler.handle_key(key.to_s)
      rescue => e
        JSBridge.error "KeyboardHandler: #{e.message}"
      end
    end
  end

  def register_callbacks
    JS.global[:rubySetColorMode] = lambda do |key_number|
      begin
        handle_color_mode(key_number.to_i)
      rescue => e
        JSBridge.error "Error in rubySetColorMode: #{e.message}"
      end
    end

    JS.global[:rubyAdjustSensitivity] = lambda do |delta|
      begin
        handle_sensitivity(delta.to_f)
      rescue => e
        JSBridge.error "Error in rubyAdjustSensitivity: #{e.message}"
      end
    end

    JS.global[:rubyShiftHue] = lambda do |delta|
      begin
        handle_hue_shift(delta.to_f)
      rescue => e
        JSBridge.error "Error in rubyShiftHue: #{e.message}"
      end
    end

    JS.global[:rubyAdjustMaxBrightness] = lambda do |delta|
      begin
        handle_brightness(delta.to_i)
      rescue => e
        JSBridge.error "Error in rubyAdjustMaxBrightness: #{e.message}"
      end
    end

    JS.global[:rubyAdjustMaxLightness] = lambda do |delta|
      begin
        handle_lightness(delta.to_i)
      rescue => e
        JSBridge.error "Error in rubyAdjustMaxLightness: #{e.message}"
      end
    end
  end
end
