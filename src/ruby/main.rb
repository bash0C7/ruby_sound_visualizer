require 'js'

class VisualizerApp
  def initialize
    @initialized = false
    @vrm_data = nil
    @audio_analyzer = AudioAnalyzer.new
    @audio_input_manager = AudioInputManager.new
    @effect_manager = EffectManager.new
    @effect_dispatcher = EffectDispatcher.new(@effect_manager)
    @vrm_dancer = VRMDancer.new
    @vrm_material_controller = VRMMaterialController.new
    @keyboard_handler = KeyboardHandler.new(@audio_input_manager)
    @debug_formatter = DebugFormatter.new(@audio_input_manager)
    @bpm_estimator = BPMEstimator.new
    @frame_counter = FrameCounter.new
    @serial_manager = SerialManager.new
    @serial_audio_source = SerialAudioSource.new
    @synth_engine = SynthEngine.new
    @oscilloscope_renderer = OscilloscopeRenderer.new
    @pen_input = PenInput.new
    @wordart_renderer = WordartRenderer.new
    @vj_pad = VJPad.new(@audio_input_manager,
                        serial_manager: @serial_manager,
                        serial_audio_source: @serial_audio_source,
                        synth_engine: @synth_engine,
                        oscilloscope_renderer: @oscilloscope_renderer,
                        wordart_renderer: @wordart_renderer,
                        pen_input: @pen_input)
  end

  def register_callbacks
    app = self

    JS.global[:rubySerialOnConnect] = lambda do |baud|
      app.on_serial_connect(baud)
    end

    JS.global[:rubySerialOnDisconnect] = lambda do
      app.on_serial_disconnect
    end

    JS.global[:rubySerialOnReceive] = lambda do |data|
      app.on_serial_receive(data)
    end

    JS.global[:rubyPenDown] = lambda do |x, y, buttons|
      app.on_pen_down(x, y, buttons)
    end

    JS.global[:rubyPenMove] = lambda do |x, y|
      app.on_pen_move(x, y)
    end

    JS.global[:rubyPenUp] = lambda do
      app.on_pen_up
    end

    JS.global[:rubyExecPrompt] = lambda do |input|
      app.on_exec_prompt(input)
    end

    JS.global[:rubyUpdateVisuals] = lambda do |freq_array, timestamp|
      app.update_visuals(freq_array, timestamp)
    end
  end

  def on_serial_connect(baud)
    @serial_manager.on_connect(baud.to_i)
    JSBridge.log "Serial connected at #{baud}bps"
  end

  def on_serial_disconnect
    @serial_manager.on_disconnect
    JSBridge.log "Serial disconnected"
  end

  def on_serial_receive(data)
    frames = @serial_manager.receive_data(data.to_s)
    if frames
      frames.each do |frame|
        next unless frame[:type] == :frequency
        @serial_audio_source.update(frame[:frequency], frame[:duty]) if @serial_audio_source
        @synth_engine.note_on(frame[:frequency], frame[:duty]) if @synth_engine
      end
    end
    last_line = @serial_manager.rx_log.last
    JS.global[:document].getElementById('serialRxDisplay')[:textContent] = last_line.to_s if last_line
  end

  def on_pen_down(x, y, buttons)
    @pen_input.start_stroke(x.to_f, y.to_f) if buttons.to_i & 1 != 0
  end

  def on_pen_move(x, y)
    @pen_input.add_point(x.to_f, y.to_f)
  end

  def on_pen_up
    @pen_input.end_stroke
  end

  def on_exec_prompt(input)
    result = @vj_pad.exec(input.to_s)
    if result[:ok]
      JSBridge.log "VJPad: #{result[:msg]}" unless result[:msg].empty?
      result[:msg]
    else
      JSBridge.error "VJPad: #{result[:msg]}"
      "ERR: #{result[:msg]}"
    end
  rescue => e
    JSBridge.error "VJPad error: #{e.message}"
    "ERR: #{e.message}"
  end

  def update_visuals(freq_array, timestamp)
    unless @initialized
      JSBridge.log "First update received, initializing effect system..."
      @initialized = true
    end

    dispatch_vj_actions
    analysis = analyze_audio(freq_array)
    update_effects(analysis)
    update_vrm(analysis)
    update_serial(analysis)
    update_pen_input
    update_wordart(analysis)
    update_frame_tracking(analysis, timestamp)
    update_debug_display(analysis)
  rescue => e
    JSBridge.error "Error in rubyUpdateVisuals: #{e.class} #{e.message}"
    JSBridge.error e.backtrace[0..4].join(", ")
  end

  private

  def dispatch_vj_actions
    @vj_pad.consume_actions.each do |action|
      @effect_dispatcher.dispatch(action[:effects]) if action[:effects]
    end
  end

  def analyze_audio(freq_array)
    analysis = @audio_analyzer.analyze(freq_array, VisualizerPolicy.sensitivity)
    @effect_manager.update(analysis, VisualizerPolicy.sensitivity)
    analysis
  end

  def update_effects(analysis)
    JSBridge.update_particles(@effect_manager.particle_data)
    JSBridge.update_geometry(@effect_manager.geometry_data)
    JSBridge.update_bloom(@effect_manager.bloom_data)
    JSBridge.update_camera(@effect_manager.camera_data)
    JSBridge.update_particle_rotation(@effect_manager.geometry_data[:rotation])
  end

  def update_vrm(analysis)
    has_vrm = JS.global[:currentVRM].typeof.to_s != "undefined"
    return unless has_vrm

    scaled = scale_analysis_for_vrm(analysis)
    @vrm_data = @vrm_dancer.update(scaled)
    JSBridge.update_vrm(@vrm_data)

    vrm_material_config = @vrm_material_controller.apply_emissive(scaled[:overall_energy])
    JSBridge.update_vrm_material(vrm_material_config)
  end

  def scale_analysis_for_vrm(analysis)
    sens = VisualizerPolicy.sensitivity
    {
      bass: [analysis[:bass] * sens, 1.0].min,
      mid: [analysis[:mid] * sens, 1.0].min,
      high: [analysis[:high] * sens, 1.0].min,
      overall_energy: [analysis[:overall_energy] * sens, 1.0].min,
      beat: analysis[:beat],
      impulse: {
        overall: @effect_manager.impulse_overall || 0.0,
        bass: @effect_manager.impulse_bass || 0.0,
        mid: @effect_manager.impulse_mid || 0.0,
        high: @effect_manager.impulse_high || 0.0
      }
    }
  end

  def update_serial(analysis)
    if @vj_pad.serial_auto_send? && @serial_manager.connected?
      frame = @serial_manager.send_audio_frame(analysis)
      JS.global.serialSend(frame) if frame
    end

    if @serial_audio_source.pending_update?
      sa_data = @serial_audio_source.consume_update
      JS.global.updateSerialAudio(
        sa_data[:frequency],
        sa_data[:duty],
        sa_data[:active] ? 1 : 0,
        sa_data[:volume]
      )
    end

    update_synth
    update_oscilloscope
  end

  def update_synth
    return unless @synth_engine

    if @synth_engine.pending_update?
      synth_data = @synth_engine.consume_update
      JSBridge.update_synth(synth_data)
    end
  end

  def update_oscilloscope
    return unless @oscilloscope_renderer&.enabled?

    # Set intensity from synth duty (0-100 → 0-1)
    if @synth_engine&.active?
      @oscilloscope_renderer.set_intensity(@synth_engine.duty / 100.0)
    else
      @oscilloscope_renderer.set_intensity(0.0)
    end

    @oscilloscope_renderer.advance_scroll(16.67)
    @oscilloscope_renderer.push_to_history
    JSBridge.update_oscilloscope(@oscilloscope_renderer.render_data)
  end

  def update_pen_input
    @pen_input.update
    JS.global.penDrawStrokes(@pen_input.to_render_json)
  end

  def update_wordart(analysis)
    return unless @wordart_renderer.active?
    @wordart_renderer.update(analysis)
    JS.global.wordartRender(@wordart_renderer.to_render_json)
  end

  def update_frame_tracking(analysis, timestamp)
    @bpm_estimator.tick
    ts = timestamp.typeof == "number" ? timestamp.to_f : 0.0
    @frame_counter.tick(ts) if ts > 0
    frame_count = @bpm_estimator.frame_count
    JSBridge.frame_count = frame_count

    beat = analysis[:beat] || {}
    if beat[:bass]
      @bpm_estimator.record_beat(frame_count, fps: @frame_counter.current_fps.to_f)
    end

    if @frame_counter.report_ready?
      JS.global[:fpsText] = @frame_counter.fps_text
      @frame_counter.clear_report
    end

    update_vrm_debug(frame_count)
    update_audio_log(analysis, frame_count)
  end

  def update_vrm_debug(frame_count)
    has_vrm = JS.global[:currentVRM].typeof.to_s != "undefined"
    return unless has_vrm && frame_count % 60 == 0

    rotations = (@vrm_data && @vrm_data[:rotations]) || []
    return unless rotations.length >= 9

    hips_rot_max = rotations[0..2].map(&:abs).max.round(3)
    spine_rot_max = rotations[3..5].map(&:abs).max.round(3)
    chest_rot_max = rotations[6..8].map(&:abs).max.round(3)
    hips_y = (@vrm_data[:hips_position_y] || 0.0).round(3)
    JS.global[:vrmDebugText] = "VRM rot: h=#{hips_rot_max} s=#{spine_rot_max} c=#{chest_rot_max} hY=#{hips_y}"
  end

  def update_debug_display(analysis)
    beat = analysis[:beat] || {}
    JS.global[:debugInfoText] = @debug_formatter.format_debug_text(analysis, beat, bpm: @bpm_estimator.estimated_bpm)
    JS.global[:paramInfoText] = @debug_formatter.format_param_text
    JS.global[:keyGuideText] = @debug_formatter.format_key_guide
  end

  def update_audio_log(analysis, frame_count)
    return unless frame_count % 60 == 0
    bass = (analysis[:bass] * 100).round(1)
    mid = (analysis[:mid] * 100).round(1)
    high = (analysis[:high] * 100).round(1)
    overall = (analysis[:overall_energy] * 100).round(1)
    JSBridge.log "Audio: Bass=#{bass}% Mid=#{mid}% High=#{high}% Overall=#{overall}% | Sensitivity: #{VisualizerPolicy.sensitivity.round(2)}x"
  end
end

# URL parameter parsing
begin
  search_str = JS.global[:location][:search].to_s
  if search_str.is_a?(String) && search_str.length > 0
    match = search_str.match(/sensitivity=([0-9.]+)/)
    VisualizerPolicy.sensitivity = match[1].to_f if match
    match_br = search_str.match(/maxBrightness=([0-9]+)/)
    VisualizerPolicy.max_brightness = match_br[1].to_i if match_br
    match_lt = search_str.match(/maxLightness=([0-9]+)/)
    VisualizerPolicy.max_lightness = match_lt[1].to_i if match_lt
  end
rescue => e
  # URL parameter parse failure: use Config defaults
end

begin
  JSBridge.log "Ruby VM started, initializing... (Sensitivity: #{VisualizerPolicy.sensitivity})"

  app = VisualizerApp.new
  app.register_callbacks
  VisualizerPolicy.register_devtool_callbacks
  SnapshotManager.register_callbacks

  JSBridge.log "Keyboard controls ready (0-3: color, 4/5: hue shift, 6/7: brightness, 8/9: lightness, +/-: sensitivity)"
  JSBridge.log "Ruby initialization complete!"

rescue => e
  JSBridge.error "Fatal error during Ruby initialization: #{e.message}"
end
