# VJ Pad: In-browser prompt DSL for real-time visualizer control.
# Commands are evaluated via instance_eval for minimal-keystroke VJ workflow.
class VJPad
  attr_reader :history, :last_result, :pending_actions

  COLOR_ALIASES = {
    red: 1, r: 1,
    yellow: 2, y: 2,
    blue: 3, b: 3,
    gray: 0, g: 0
  }.freeze

  COLOR_NAMES = { 0 => 'gray', 1 => 'red', 2 => 'yellow', 3 => 'blue' }.freeze

  def initialize(audio_input_manager = nil)
    @audio_input_manager = audio_input_manager
    @history = []
    @last_result = nil
    @pending_actions = []
  end

  def exec(input)
    input = input.to_s.strip
    return { ok: true, msg: '' } if input.empty?
    @history << input
    result = instance_eval(input)
    @last_result = result.to_s
    { ok: true, msg: @last_result }
  rescue SyntaxError, StandardError => e
    @last_result = e.message
    { ok: false, msg: e.message }
  end

  def consume_actions
    actions = @pending_actions.dup
    @pending_actions = []
    actions
  end

  # --- DSL Commands ---

  def c(mode = :_get)
    if mode == :_get
      name = COLOR_NAMES[ColorPalette.get_hue_mode] || 'gray'
      return "color: #{name}"
    end
    resolved = mode.is_a?(Symbol) ? (COLOR_ALIASES[mode] || 0) : mode.to_i
    actual_mode = resolved == 0 ? nil : resolved
    ColorPalette.set_hue_mode(actual_mode)
    "color: #{COLOR_NAMES[resolved] || 'gray'}"
  end

  def h(deg = :_get)
    if deg == :_get
      return "hue: #{ColorPalette.get_hue_offset.round(1)}"
    end
    ColorPalette.set_hue_offset(deg.to_f)
    "hue: #{ColorPalette.get_hue_offset.round(1)}"
  end

  def s(val = :_get)
    return "sens: #{VisualizerPolicy.sensitivity}" if val == :_get
    VisualizerPolicy.sensitivity = val.to_f
    "sens: #{VisualizerPolicy.sensitivity}"
  end

  def br(val = :_get)
    return "bright: #{VisualizerPolicy.max_brightness}" if val == :_get
    VisualizerPolicy.max_brightness = val.to_i
    "bright: #{VisualizerPolicy.max_brightness}"
  end

  def lt(val = :_get)
    return "light: #{VisualizerPolicy.max_lightness}" if val == :_get
    VisualizerPolicy.max_lightness = val.to_i
    "light: #{VisualizerPolicy.max_lightness}"
  end

  def em(val = :_get)
    return "emissive: #{VisualizerPolicy.max_emissive}" if val == :_get
    VisualizerPolicy.max_emissive = val.to_f
    "emissive: #{VisualizerPolicy.max_emissive}"
  end

  def bm(val = :_get)
    return "bloom: #{VisualizerPolicy.max_bloom}" if val == :_get
    VisualizerPolicy.max_bloom = val.to_f
    "bloom: #{VisualizerPolicy.max_bloom}"
  end

  def x
    VisualizerPolicy.exclude_max = !VisualizerPolicy.exclude_max
    "exclude_max: #{VisualizerPolicy.exclude_max}"
  end

  def r
    VisualizerPolicy.reset_runtime
    ColorPalette.set_hue_mode(nil)
    "reset done"
  end

  def i
    cn = COLOR_NAMES[ColorPalette.get_hue_mode] || 'gray'
    ho = ColorPalette.get_hue_offset.round(1)
    se = VisualizerPolicy.sensitivity
    b = VisualizerPolicy.max_brightness
    l = VisualizerPolicy.max_lightness
    e = VisualizerPolicy.max_emissive
    bl = VisualizerPolicy.max_bloom
    ex = VisualizerPolicy.exclude_max
    "c:#{cn} h:#{ho} | s:#{se} br:#{b} lt:#{l} | em:#{e} bm:#{bl} x:#{ex}"
  end

  # --- Audio Input Commands ---

  def mic(val = :_get)
    if @audio_input_manager
      # Use AudioInputManager for state management
      is_muted = @audio_input_manager.mic_muted?
      if val == :_get
        return "mic: #{is_muted ? 'muted' : 'on'}"
      end
      target_mute = val.to_i == 0
      if target_mute
        @audio_input_manager.mute_mic
      else
        @audio_input_manager.unmute_mic
      end
      JS.global.setMicMute(target_mute) if JS.global.respond_to?(:setMicMute)
      "mic: #{target_mute ? 'muted' : 'on'}"
    else
      # Fallback to JS.global for backward compatibility
      muted = JS.global[:micMuted]
      is_muted = muted == true
      if val == :_get
        return "mic: #{is_muted ? 'muted' : 'on'}"
      end
      target_mute = val.to_i == 0
      JS.global.setMicMute(target_mute)
      "mic: #{target_mute ? 'muted' : 'on'}"
    end
  end

  def tab(val = :_get)
    if @audio_input_manager
      # Use AudioInputManager for state management
      is_active = @audio_input_manager.tab_capture?
      if val == :_get
        return "tab: #{is_active ? 'on' : 'off'}"
      end
      # val is non-:_get, so we're setting/toggling
      @audio_input_manager.switch_to_tab
      JS.global.toggleTabCapture() if JS.global.respond_to?(:toggleTabCapture)
      "tab: toggled"
    else
      # Fallback to JS.global for backward compatibility
      stream = JS.global[:tabStream]
      is_active = stream.respond_to?(:typeof) ? stream.typeof.to_s != "undefined" && stream.typeof.to_s != "null" : !!stream
      if val == :_get
        return "tab: #{is_active ? 'on' : 'off'}"
      end
      JS.global.toggleTabCapture()
      "tab: toggled"
    end
  end

  # --- Plugin Commands ---
  # Plugin-defined commands (burst, flash, etc.) are resolved via method_missing.
  # Plugins register themselves via VJPlugin.define(:name) { ... }.

  def method_missing(name, *args, &block)
    plugin = VJPlugin.find(name)
    if plugin
      execute_plugin(plugin, args)
    else
      super
    end
  end

  def respond_to_missing?(name, include_private = false)
    VJPlugin.find(name) ? true : super
  end

  private

  def execute_plugin(plugin, args)
    param_keys = plugin.params.keys
    params = {}
    args.each_with_index do |arg, i|
      params[param_keys[i]] = arg if i < param_keys.length
    end

    effects = plugin.execute(params)
    @pending_actions << { type: :plugin, name: plugin.name, effects: effects }
    plugin.format_result(args)
  end
end
