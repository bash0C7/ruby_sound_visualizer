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

  def initialize
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
    muted = JS.global[:micMuted]
    is_muted = muted == true
    if val == :_get
      return "mic: #{is_muted ? 'muted' : 'on'}"
    end
    target_mute = val.to_i == 0
    JS.global.setMicMute(target_mute)
    "mic: #{target_mute ? 'muted' : 'on'}"
  end

  def tab(val = :_get)
    stream = JS.global[:tabStream]
    is_active = stream.respond_to?(:typeof) ? stream.typeof.to_s != "undefined" && stream.typeof.to_s != "null" : !!stream
    if val == :_get
      return "tab: #{is_active ? 'on' : 'off'}"
    end
    JS.global.toggleTabCapture()
    "tab: toggled"
  end

  # --- Action Commands ---

  def burst(force = nil)
    f = force ? force.to_f : 1.0
    @pending_actions << { type: :burst, force: f }
    force ? "burst: #{f}" : "burst!"
  end

  def flash(intensity = nil)
    v = intensity ? intensity.to_f : 1.0
    @pending_actions << { type: :flash, intensity: v }
    intensity ? "flash: #{v}" : "flash!"
  end
end
