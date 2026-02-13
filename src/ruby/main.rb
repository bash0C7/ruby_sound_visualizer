require 'js'

$initialized = false
$audio_analyzer = nil
$audio_input_manager = nil
$effect_manager = nil
$vrm_dancer = nil
$vrm_material_controller = nil
$keyboard_handler = nil
$debug_formatter = nil
$bpm_estimator = nil
$frame_counter = nil
$vj_pad = nil
$frame_count = 0  # Kept for JSBridge debug logging throttle

# URL parameter parsing -> Config
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

  $audio_analyzer = AudioAnalyzer.new
  $audio_input_manager = AudioInputManager.new
  $effect_manager = EffectManager.new
  $effect_dispatcher = EffectDispatcher.new($effect_manager)
  $vrm_dancer = VRMDancer.new
  $vrm_material_controller = VRMMaterialController.new
  $keyboard_handler = KeyboardHandler.new($audio_input_manager)
  $debug_formatter = DebugFormatter.new($audio_input_manager)
  $bpm_estimator = BPMEstimator.new
  $frame_counter = FrameCounter.new
  $vj_pad = VJPad.new($audio_input_manager)
  VisualizerPolicy.register_devtool_callbacks

  # VJ Pad prompt callback: receives command string from browser prompt UI
  JS.global[:rubyExecPrompt] = lambda do |input|
    begin
      result = $vj_pad.exec(input.to_s)
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
  end

  # Main update callback: receives frequency data and timestamp from JS
  JS.global[:rubyUpdateVisuals] = lambda do |freq_array, timestamp|
    begin
      unless $initialized
        JSBridge.log "First update received, initializing effect system..."
        $initialized = true
      end

      # Consume VJPad pending actions (plugin-dispatched effects)
      if $vj_pad
        $vj_pad.consume_actions.each do |action|
          $effect_dispatcher.dispatch(action[:effects]) if action[:effects]
        end
      end

      analysis = $audio_analyzer.analyze(freq_array, VisualizerPolicy.sensitivity)
      $effect_manager.update(analysis, VisualizerPolicy.sensitivity)

      # Send visual data to JavaScript
      JSBridge.update_particles($effect_manager.particle_data)
      JSBridge.update_geometry($effect_manager.geometry_data)
      JSBridge.update_bloom($effect_manager.bloom_data)
      JSBridge.update_camera($effect_manager.camera_data)
      JSBridge.update_particle_rotation($effect_manager.geometry_data[:rotation])

      # VRM dance update (only if VRM is loaded)
      has_vrm = JS.global[:currentVRM].typeof.to_s != "undefined"

      if has_vrm
        scaled_for_vrm = {
          bass: [analysis[:bass] * VisualizerPolicy.sensitivity, 1.0].min,
          mid: [analysis[:mid] * VisualizerPolicy.sensitivity, 1.0].min,
          high: [analysis[:high] * VisualizerPolicy.sensitivity, 1.0].min,
          overall_energy: [analysis[:overall_energy] * VisualizerPolicy.sensitivity, 1.0].min,
          beat: analysis[:beat],
          impulse: {
            overall: $effect_manager.impulse_overall || 0.0,
            bass: $effect_manager.impulse_bass || 0.0,
            mid: $effect_manager.impulse_mid || 0.0,
            high: $effect_manager.impulse_high || 0.0
          }
        }
        vrm_data = $vrm_dancer.update(scaled_for_vrm)
        JSBridge.update_vrm(vrm_data)

        vrm_material_config = $vrm_material_controller.apply_emissive(scaled_for_vrm[:overall_energy])
        JSBridge.update_vrm_material(vrm_material_config)
      end

      # Frame tracking (Ruby-side FPS calculation)
      $bpm_estimator.tick
      ts = timestamp.typeof == "number" ? timestamp.to_f : 0.0
      $frame_counter.tick(ts) if ts > 0
      frame_count = $bpm_estimator.frame_count
      $frame_count = frame_count  # Sync for JSBridge debug logging

      # BPM estimation
      beat = analysis[:beat] || {}
      if beat[:bass]
        $bpm_estimator.record_beat(frame_count, fps: $frame_counter.current_fps.to_f)
      end

      # Debug display update (once per second when FPS report is ready)
      if $frame_counter.report_ready?
        JS.global[:fpsText] = $frame_counter.fps_text
        $frame_counter.clear_report
      end

      # VRM debug info (every 60 frames, only if VRM loaded)
      if has_vrm && frame_count % 60 == 0
        rotations = vrm_data[:rotations] || []
        if rotations.length >= 9
          hips_rot_max = rotations[0..2].map(&:abs).max.round(3)
          spine_rot_max = rotations[3..5].map(&:abs).max.round(3)
          chest_rot_max = rotations[6..8].map(&:abs).max.round(3)
          hips_y = (vrm_data[:hips_position_y] || 0.0).round(3)
          JS.global[:vrmDebugText] = "VRM rot: h=#{hips_rot_max} s=#{spine_rot_max} c=#{chest_rot_max} hY=#{hips_y}"
        end
      end

      # Debug info (formatted in Ruby, displayed every frame for responsiveness)
      JS.global[:debugInfoText] = $debug_formatter.format_debug_text(analysis, beat, bpm: $bpm_estimator.estimated_bpm)
      JS.global[:paramInfoText] = $debug_formatter.format_param_text
      JS.global[:keyGuideText] = $debug_formatter.format_key_guide

      # Periodic audio log
      if frame_count % 60 == 0
        bass = (analysis[:bass] * 100).round(1)
        mid = (analysis[:mid] * 100).round(1)
        high = (analysis[:high] * 100).round(1)
        overall = (analysis[:overall_energy] * 100).round(1)
        JSBridge.log "Audio: Bass=#{bass}% Mid=#{mid}% High=#{high}% Overall=#{overall}% | Sensitivity: #{VisualizerPolicy.sensitivity.round(2)}x"
      end
    rescue => e
      JSBridge.error "Error in rubyUpdateVisuals: #{e.class} #{e.message}"
      JSBridge.error e.backtrace[0..4].join(", ")
    end
  end

  JSBridge.log "Keyboard controls ready (0-3: color, 4/5: hue shift, 6/7: brightness, 8/9: lightness, +/-: sensitivity)"
  JSBridge.log "Ruby initialization complete!"

rescue => e
  JSBridge.error "Fatal error during Ruby initialization: #{e.message}"
end
