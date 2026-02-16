class VJPad
  attr_reader :history, :last_result, :pending_actions

  COLOR_ALIASES = {
    red: 1, r: 1,
    yellow: 2, y: 2,
    blue: 3, b: 3,
    gray: 0, g: 0
  }.freeze

  COLOR_NAMES = { 0 => 'gray', 1 => 'red', 2 => 'yellow', 3 => 'blue' }.freeze

  # VisualizerPolicy parameter commands: { command => { label:, policy:, cast:, suffix: } }
  PARAM_COMMANDS = {
    s:   { label: 'sens',           policy: :sensitivity,                    cast: :to_f },
    ig:  { label: 'gain',           policy: :input_gain,         suffix: 'dB', cast: :to_f },
    br:  { label: 'bright',         policy: :max_brightness,                 cast: :to_i },
    lt:  { label: 'light',          policy: :max_lightness,                  cast: :to_i },
    em:  { label: 'emissive',       policy: :max_emissive,                   cast: :to_f },
    bm:  { label: 'bloom',          policy: :max_bloom,                      cast: :to_f },
    bbs: { label: 'bloom_base',     policy: :bloom_base_strength,            cast: :to_f },
    bes: { label: 'bloom_energy',   policy: :bloom_energy_scale,             cast: :to_f },
    bis: { label: 'bloom_impulse',  policy: :bloom_impulse_scale,            cast: :to_f },
    pp:  { label: 'particle_prob',  policy: :particle_explosion_base_prob,   cast: :to_f },
    pf:  { label: 'particle_force', policy: :particle_explosion_force_scale, cast: :to_f },
    fr:  { label: 'friction',       policy: :particle_friction,              cast: :to_f },
    vs:  { label: 'smoothing',      policy: :visual_smoothing,               cast: :to_f },
    id:  { label: 'impulse_decay',  policy: :impulse_decay,                  cast: :to_f },
  }.freeze

  PARAM_COMMANDS.each do |cmd, spec|
    define_method(cmd) do |val = :_get|
      if val == :_get
        return "#{spec[:label]}: #{VisualizerPolicy.send(spec[:policy])}#{spec[:suffix]}"
      end
      VisualizerPolicy.send(:"#{spec[:policy]}=", val.send(spec[:cast]))
      "#{spec[:label]}: #{VisualizerPolicy.send(spec[:policy])}#{spec[:suffix]}"
    end
  end

  def initialize(audio_input_manager = nil, serial_manager: nil, serial_audio_source: nil,
                 wordart_renderer: nil, pen_input: nil)
    @audio_input_manager = audio_input_manager
    @serial_manager = serial_manager
    @serial_audio_source = serial_audio_source
    @wordart_renderer = wordart_renderer
    @pen_input = pen_input
    @history = []
    @last_result = nil
    @pending_actions = []
    @serial_auto_send = false
  end

  def exec(input)
    input = input.to_s.strip
    return { ok: true, msg: '' } if input.empty?
    input = preprocess_text_command(input)
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

  # --- Color & Hue Commands ---

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
    ig = VisualizerPolicy.input_gain
    b = VisualizerPolicy.max_brightness
    l = VisualizerPolicy.max_lightness
    e = VisualizerPolicy.max_emissive
    bl = VisualizerPolicy.max_bloom
    ex = VisualizerPolicy.exclude_max
    "c:#{cn} h:#{ho} | s:#{se} ig:#{ig}dB br:#{b} lt:#{l} | em:#{e} bm:#{bl} x:#{ex}"
  end

  # --- Audio Input Commands ---

  def mic(val = :_get)
    return "mic: unavailable" unless @audio_input_manager

    if val == :_get
      return "mic: #{@audio_input_manager.mic_muted? ? 'muted' : 'on'}"
    end
    target_mute = val.to_i == 0
    target_mute ? @audio_input_manager.mute_mic : @audio_input_manager.unmute_mic
    JS.global.setMicMute(target_mute) if JS.global.respond_to?(:setMicMute)
    "mic: #{target_mute ? 'muted' : 'on'}"
  end

  def tab(val = :_get)
    return "tab: unavailable" unless @audio_input_manager

    if val == :_get
      return "tab: #{@audio_input_manager.tab_capture? ? 'on' : 'off'}"
    end
    @audio_input_manager.switch_to_tab
    JS.global.toggleTabCapture() if JS.global.respond_to?(:toggleTabCapture)
    "tab: toggled"
  end

  # --- WordArt Commands ---

  def wa(text = '')
    return "wordart: not available" unless @wordart_renderer
    return "wordart: empty text" if text.to_s.strip.empty?
    @wordart_renderer.trigger(text.to_s)
    "wordart: #{text}"
  end

  def was
    return "wordart: not available" unless @wordart_renderer
    @wordart_renderer.stop
    "wordart: stopped"
  end

  # --- Pen Input Commands ---

  def pc
    return "pen: not available" unless @pen_input
    @pen_input.clear
    "pen: cleared"
  end

  # --- Serial Commands ---

  def serial_manager
    @serial_manager
  end

  def serial_auto_send?
    @serial_auto_send
  end

  def sc
    return "serial: not available" unless @serial_manager
    baud = @serial_manager.baud_rate
    JS.global.serialConnect(baud)
    "serial: connecting at #{baud}bps..."
  end

  def sd
    return "serial: not available" unless @serial_manager
    JS.global.serialDisconnect()
    @serial_manager.on_disconnect
  end

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

  def sr(count = 10)
    return "serial: not available" unless @serial_manager
    lines = @serial_manager.rx_log.last(count.to_i)
    return "serial RX: (empty)" if lines.empty?
    "serial RX:\n#{lines.join("\n")}"
  end

  def st(count = 10)
    return "serial: not available" unless @serial_manager
    lines = @serial_manager.tx_log.last(count.to_i)
    return "serial TX: (empty)" if lines.empty?
    "serial TX:\n#{lines.join("\n")}"
  end

  def sb(rate = :_get)
    return "serial: not available" unless @serial_manager
    if rate == :_get
      return "serial baud: #{@serial_manager.baud_rate}"
    end
    @serial_manager.set_baud(rate.to_i)
  end

  def si
    return "serial: not available" unless @serial_manager
    @serial_manager.status
  end

  def sa(val = :_get)
    return "serial: not available" unless @serial_manager
    if val == :_get
      return "serial auto: #{@serial_auto_send ? 'on' : 'off'}"
    end
    @serial_auto_send = val.to_i != 0
    "serial auto: #{@serial_auto_send ? 'on' : 'off'}"
  end

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

  # --- Serial Audio Commands ---

  def sao(val = :_get)
    return "serial_audio: not available" unless @serial_audio_source
    if val == :_get
      return "serial_audio: #{@serial_audio_source.active? ? 'on' : 'off'}"
    end
    if val.to_i != 0
      @serial_audio_source.start
    else
      @serial_audio_source.stop
    end
    "serial_audio: #{@serial_audio_source.active? ? 'on' : 'off'}"
  end

  def sav(val = :_get)
    return "serial_audio: not available" unless @serial_audio_source
    if val == :_get
      return "serial_audio vol: #{(@serial_audio_source.volume * 100).round}%"
    end
    @serial_audio_source.set_volume(val.to_f / 100.0)
    "serial_audio vol: #{(@serial_audio_source.volume * 100).round}%"
  end

  def sai
    return "serial_audio: not available" unless @serial_audio_source
    @serial_audio_source.status
  end

  def sad
    return "serial_audio: not available" unless @serial_audio_source
    JS.global.showSerialAudioDevicePicker()
    "serial_audio: device picker opened"
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

  def preprocess_text_command(input)
    input.sub(/\A(wa)\s+(?!["'])(.+)/) { "#{$1} \"#{$2.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}\"" }
  end

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
