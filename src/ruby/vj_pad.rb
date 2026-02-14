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

  def initialize(audio_input_manager = nil, serial_manager: nil)
    @audio_input_manager = audio_input_manager
    @serial_manager = serial_manager
    @history = []
    @last_result = nil
    @pending_actions = []
    @serial_auto_send = false
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

  # --- Audio-reactive Parameter Commands ---

  def bbs(val = :_get)
    return "bloom_base: #{VisualizerPolicy.bloom_base_strength}" if val == :_get
    VisualizerPolicy.bloom_base_strength = val.to_f
    "bloom_base: #{VisualizerPolicy.bloom_base_strength}"
  end

  def bes(val = :_get)
    return "bloom_energy: #{VisualizerPolicy.bloom_energy_scale}" if val == :_get
    VisualizerPolicy.bloom_energy_scale = val.to_f
    "bloom_energy: #{VisualizerPolicy.bloom_energy_scale}"
  end

  def bis(val = :_get)
    return "bloom_impulse: #{VisualizerPolicy.bloom_impulse_scale}" if val == :_get
    VisualizerPolicy.bloom_impulse_scale = val.to_f
    "bloom_impulse: #{VisualizerPolicy.bloom_impulse_scale}"
  end

  def pp(val = :_get)
    return "particle_prob: #{VisualizerPolicy.particle_explosion_base_prob}" if val == :_get
    VisualizerPolicy.particle_explosion_base_prob = val.to_f
    "particle_prob: #{VisualizerPolicy.particle_explosion_base_prob}"
  end

  def pf(val = :_get)
    return "particle_force: #{VisualizerPolicy.particle_explosion_force_scale}" if val == :_get
    VisualizerPolicy.particle_explosion_force_scale = val.to_f
    "particle_force: #{VisualizerPolicy.particle_explosion_force_scale}"
  end

  def fr(val = :_get)
    return "friction: #{VisualizerPolicy.particle_friction}" if val == :_get
    VisualizerPolicy.particle_friction = val.to_f
    "friction: #{VisualizerPolicy.particle_friction}"
  end

  def vs(val = :_get)
    return "smoothing: #{VisualizerPolicy.visual_smoothing}" if val == :_get
    VisualizerPolicy.visual_smoothing = val.to_f
    "smoothing: #{VisualizerPolicy.visual_smoothing}"
  end

  def id(val = :_get)
    return "impulse_decay: #{VisualizerPolicy.impulse_decay}" if val == :_get
    VisualizerPolicy.impulse_decay = val.to_f
    "impulse_decay: #{VisualizerPolicy.impulse_decay}"
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

  # --- WordArt Commands ---

  # wa "text" - display 90s WordArt text animation
  def wa(text = '')
    return "wordart: not available" unless $wordart_renderer
    return "wordart: empty text" if text.to_s.strip.empty?
    $wordart_renderer.trigger(text.to_s)
    "wordart: #{text}"
  end

  # was - stop current WordArt animation
  def was
    return "wordart: not available" unless $wordart_renderer
    $wordart_renderer.stop
    "wordart: stopped"
  end

  # --- Pen Input Commands ---

  # pc - clear all pen strokes
  def pc
    return "pen: not available" unless $pen_input
    $pen_input.clear
    "pen: cleared"
  end

  # --- Serial Commands ---

  def serial_manager
    @serial_manager
  end

  def serial_auto_send?
    @serial_auto_send
  end

  # sc - serial connect (triggers JS requestPort + open)
  def sc
    return "serial: not available" unless @serial_manager
    baud = @serial_manager.baud_rate
    JS.global.serialConnect(baud)
    "serial: connecting at #{baud}bps..."
  end

  # sd - serial disconnect
  def sd
    return "serial: not available" unless @serial_manager
    JS.global.serialDisconnect()
    @serial_manager.on_disconnect
  end

  # ss "text" - serial send text
  def ss(text = '')
    return "serial: not available" unless @serial_manager
    msg = @serial_manager.send_text(text.to_s)
    if msg && !msg.start_with?("serial:")
      JS.global.serialSend(msg)
      "serial TX: #{msg}"
    else
      msg
    end
  end

  # sr - show received log (last 10 lines)
  def sr(count = 10)
    return "serial: not available" unless @serial_manager
    lines = @serial_manager.rx_log.last(count.to_i)
    return "serial RX: (empty)" if lines.empty?
    "serial RX:\n#{lines.join("\n")}"
  end

  # st - show transmit log (last 10 lines)
  def st(count = 10)
    return "serial: not available" unless @serial_manager
    lines = @serial_manager.tx_log.last(count.to_i)
    return "serial TX: (empty)" if lines.empty?
    "serial TX:\n#{lines.join("\n")}"
  end

  # sb rate - set baud rate (38400 or 115200)
  def sb(rate = :_get)
    return "serial: not available" unless @serial_manager
    if rate == :_get
      return "serial baud: #{@serial_manager.baud_rate}"
    end
    @serial_manager.set_baud(rate.to_i)
  end

  # si - serial info/status
  def si
    return "serial: not available" unless @serial_manager
    @serial_manager.status
  end

  # sa 1/0 - enable/disable auto-send of audio frames per visualizer frame
  def sa(val = :_get)
    return "serial: not available" unless @serial_manager
    if val == :_get
      return "serial auto: #{@serial_auto_send ? 'on' : 'off'}"
    end
    @serial_auto_send = val.to_i != 0
    "serial auto: #{@serial_auto_send ? 'on' : 'off'}"
  end

  # scl - clear serial logs
  def scl(target = 'all')
    return "serial: not available" unless @serial_manager
    case target.to_s
    when 'rx'
      @serial_manager.clear_rx_log
    when 'tx'
      @serial_manager.clear_tx_log
    else
      @serial_manager.clear_rx_log
      @serial_manager.clear_tx_log
      "serial: logs cleared"
    end
  end

  # --- Plugin Discovery ---

  def plugins
    VJPlugin.all.map { |p|
      params_str = p.params.map { |k, cfg|
        range = cfg[:range] ? " (#{cfg[:range]})" : ""
        "#{k}=#{cfg[:default]}#{range}"
      }.join(", ")
      "#{p.name}: #{p.description} [#{params_str}]"
    }.join("\n")
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

    resolved = plugin.resolve_params(params)
    effects = plugin.execute(params)
    @pending_actions << { type: :plugin, name: plugin.name, effects: effects }
    plugin.format_result(args.empty? ? {} : resolved)
  end
end
