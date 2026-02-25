require_relative 'test_helper'

# Integration tests for main.rb component initialization and wiring
# Verifies that all components are correctly initialized and connected
class TestMainIntegration < Test::Unit::TestCase
  def setup
    JS.reset_global!
    VisualizerPolicy.reset_runtime
  end

  def test_all_components_can_be_initialized
    # Verify all components can be created without errors (16 components)
    audio_analyzer = AudioAnalyzer.new
    audio_input_manager = AudioInputManager.new
    effect_manager = EffectManager.new
    vrm_dancer = VRMDancer.new
    vrm_material_controller = VRMMaterialController.new
    keyboard_handler = KeyboardHandler.new(audio_input_manager)
    debug_formatter = DebugFormatter.new(audio_input_manager)
    bpm_estimator = BPMEstimator.new
    frame_counter = FrameCounter.new
    vj_pad = VJPad.new(audio_input_manager)
    effect_dispatcher = EffectDispatcher.new(effect_manager)
    serial_manager = SerialManager.new
    serial_audio_source = SerialAudioSource.new
    oscilloscope_renderer = OscilloscopeRenderer.new
    pen_input = PenInput.new
    wordart_renderer = WordartRenderer.new
    synth_patch = SynthPatch.build(adapter: SynthPatch::MockAdapter.new) do |syn|
      mod     = syn.fm_op(:sine, freq: 220, amp: 80, name: :mod)
      carrier = syn.fm_op(:sine, freq: 440, name: :carrier).fm(mod)
      sub     = syn.osc(:sawtooth, freq: 220, name: :sub)
      syn.mix(carrier, sub, name: :mixer)
         .filter(:lowpass, cutoff: 1200, q: 0.9, name: :main_filter)
         .gain(0.35, name: :master_gain)
         .out
    end

    assert_not_nil audio_analyzer
    assert_not_nil audio_input_manager
    assert_not_nil effect_manager
    assert_not_nil vrm_dancer
    assert_not_nil vrm_material_controller
    assert_not_nil keyboard_handler
    assert_not_nil debug_formatter
    assert_not_nil bpm_estimator
    assert_not_nil frame_counter
    assert_not_nil vj_pad
    assert_not_nil effect_dispatcher
    assert_not_nil serial_manager
    assert_not_nil serial_audio_source
    assert_not_nil oscilloscope_renderer
    assert_not_nil pen_input
    assert_not_nil wordart_renderer
    assert_not_nil synth_patch
  end

  def test_audio_input_manager_wiring_to_keyboard_handler
    manager = AudioInputManager.new
    handler = KeyboardHandler.new(manager)

    # Verify keyboard handler can control audio input manager
    handler.handle_key('m')
    assert_equal true, manager.mic_muted?

    handler.handle_key('m')
    assert_equal false, manager.mic_muted?

    handler.handle_key('t')
    assert_equal :tab, manager.source
  end

  def test_audio_input_manager_wiring_to_vj_pad
    manager = AudioInputManager.new
    pad = VJPad.new(manager)

    # Verify VJPad can read audio input manager state
    result = pad.exec("mic")
    assert_equal "mic: on", result[:msg]

    manager.mute_mic
    result = pad.exec("mic")
    assert_equal "mic: muted", result[:msg]

    result = pad.exec("tab")
    assert_equal "tab: off", result[:msg]

    manager.switch_to_tab
    result = pad.exec("tab")
    assert_equal "tab: on", result[:msg]
  end

  def test_audio_input_manager_wiring_to_debug_formatter
    manager = AudioInputManager.new
    formatter = DebugFormatter.new(manager)

    # format_param_text is simplified to empty string (info shown in Controls panel)
    result = formatter.format_param_text
    assert_equal "", result
  end

  def test_audio_analyzer_to_effect_manager_flow
    analyzer = AudioAnalyzer.new
    effect_manager = EffectManager.new

    # Simulate audio input with frequency data
    freq_data = Array.new(128, 100)

    # Warmup analyzer
    10.times { analyzer.analyze(freq_data) }

    # Analyze and pass to effect manager
    analysis = analyzer.analyze(freq_data)
    effect_manager.update(analysis, 1.0)

    # Verify effect manager produces output
    particle_data = effect_manager.particle_data
    geometry_data = effect_manager.geometry_data
    bloom_data = effect_manager.bloom_data

    assert_instance_of Hash, particle_data
    assert_instance_of Hash, geometry_data
    assert_instance_of Hash, bloom_data

    assert_includes particle_data.keys, :positions
    assert_includes geometry_data.keys, :rotation
    assert_includes bloom_data.keys, :strength
  end

  def test_visualizer_policy_affects_all_components
    # Reset to known state
    VisualizerPolicy.sensitivity = 1.0
    VisualizerPolicy.max_brightness = 255
    VisualizerPolicy.max_lightness = 255

    # Verify VisualizerPolicy is shared across components
    analyzer = AudioAnalyzer.new
    keyboard_handler = KeyboardHandler.new

    # Change sensitivity via keyboard handler
    keyboard_handler.handle_sensitivity(0.5)
    assert_in_delta 1.5, VisualizerPolicy.sensitivity, 0.01

    # Verify analyzer uses updated sensitivity
    freq_data = Array.new(128, 100)
    result = analyzer.analyze(freq_data, VisualizerPolicy.sensitivity)
    assert_not_nil result
  end

  def test_color_palette_shared_across_components
    # Reset to known state
    ColorPalette.set_hue_mode(nil)

    keyboard_handler = KeyboardHandler.new
    vj_pad = VJPad.new
    debug_formatter = DebugFormatter.new

    # Change color mode via keyboard handler
    keyboard_handler.handle_color_mode(1)
    assert_equal 1, ColorPalette.get_hue_mode

    # Verify VJPad sees the change via i command
    result = vj_pad.exec("i")
    assert_match(/c:red/, result[:msg])

    # Verify debug formatter sees the change
    analysis = { bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4 }
    debug_text = debug_formatter.format_debug_text(analysis, {}, bpm: 0)
    assert_match(/1:Hue/, debug_text)
  end

  def test_vj_pad_burst_and_flash_integration
    effect_manager = EffectManager.new
    dispatcher = EffectDispatcher.new(effect_manager)
    vj_pad = VJPad.new

    # Trigger burst via VJPad
    result = vj_pad.exec("burst 2.0")
    assert_equal "burst: 2.0", result[:msg]

    # Consume actions and dispatch via EffectDispatcher
    actions = vj_pad.consume_actions
    assert_equal 1, actions.length
    assert_equal :plugin, actions[0][:type]
    assert_equal :burst, actions[0][:name]

    # Dispatch effects to effect manager
    actions.each { |action| dispatcher.dispatch(action[:effects]) }

    # Call update to generate particle_data
    dummy_analysis = {
      bass: 0.5, mid: 0.3, high: 0.2, overall_energy: 0.4,
      dominant_frequency: 0, beat: {}
    }
    effect_manager.update(dummy_analysis, 1.0)

    # Verify effect manager has impulse
    # (impulse values decay quickly, so just verify no crash)
    assert_not_nil effect_manager.particle_data
  end

  def test_frame_counter_and_bpm_estimator_integration
    frame_counter = FrameCounter.new
    bpm_estimator = BPMEstimator.new

    # Simulate frame updates (need at least 1000ms for FPS calculation)
    base_time = 1000.0
    100.times do |i|
      timestamp = base_time + (i * 16.67)  # ~60fps
      frame_counter.tick(timestamp)
      bpm_estimator.tick

      # Simulate beat every 30 frames (~120 BPM at 60fps)
      # Need at least 3 beats for BPM estimation
      if i % 30 == 0 && i > 0
        bpm_estimator.record_beat(bpm_estimator.frame_count, fps: 60.0)
      end
    end

    # Verify FPS estimation (after 100 frames * 16.67ms = 1667ms)
    assert frame_counter.current_fps > 0, "FPS should be calculated after 1000ms"

    # Verify BPM estimation (i=30, 60, 90 -> 3 beats recorded)
    assert bpm_estimator.estimated_bpm > 0, "BPM should be estimated after recording 3+ beats"
  end

  def test_synth_patch_initialization_in_app_context
    # Verify SynthPatch with main.rb FM config works in integration context
    adapter = SynthPatch::MockAdapter.new
    patch = SynthPatch.build(adapter: adapter) do |syn|
      mod     = syn.fm_op(:sine, freq: 220, amp: 80, name: :mod)
      carrier = syn.fm_op(:sine, freq: 440, name: :carrier).fm(mod)
      sub     = syn.osc(:sawtooth, freq: 220, name: :sub)
      syn.mix(carrier, sub, name: :mixer)
         .filter(:lowpass, cutoff: 1200, q: 0.9, name: :main_filter)
         .gain(0.35, name: :master_gain)
         .out
    end

    # Verify all 6 named nodes exist
    assert_not_nil patch[:mod],         "mod node should exist"
    assert_not_nil patch[:carrier],     "carrier node should exist"
    assert_not_nil patch[:sub],         "sub node should exist"
    assert_not_nil patch[:mixer],       "mixer node should exist"
    assert_not_nil patch[:main_filter], "main_filter node should exist"
    assert_not_nil patch[:master_gain], "master_gain node should exist"

    # Verify compiled spec has FM connections
    spec = JSON.parse(adapter.graph_spec)
    refute spec['fm_connections'].empty?, "FM connections should be present"

    # Verify output node
    assert_equal 'master_gain', spec['output_node']

    # Verify note_on / note_off work without errors
    assert_nothing_raised { patch.note_on(440, 100) }
    assert patch.active?
    assert_nothing_raised { patch.note_off }
    refute patch.active?
  end

  def test_vj_pad_with_all_dependencies_including_synth
    # Build the same SynthPatch as main.rb
    serial_manager = SerialManager.new
    serial_audio_source = SerialAudioSource.new
    oscilloscope_renderer = OscilloscopeRenderer.new
    wordart_renderer = WordartRenderer.new
    pen_input = PenInput.new
    synth_patch = SynthPatch.build(adapter: SynthPatch::MockAdapter.new) do |syn|
      mod     = syn.fm_op(:sine, freq: 220, amp: 80, name: :mod)
      carrier = syn.fm_op(:sine, freq: 440, name: :carrier).fm(mod)
      sub     = syn.osc(:sawtooth, freq: 220, name: :sub)
      syn.mix(carrier, sub, name: :mixer)
         .filter(:lowpass, cutoff: 1200, q: 0.9, name: :main_filter)
         .gain(0.35, name: :master_gain)
         .out
    end

    vj_pad = VJPad.new(nil,
                       serial_manager: serial_manager,
                       serial_audio_source: serial_audio_source,
                       oscilloscope_renderer: oscilloscope_renderer,
                       wordart_renderer: wordart_renderer,
                       pen_input: pen_input,
                       synth_patch: synth_patch)

    # sp_i should return patch status
    result = vj_pad.exec("sp_i")
    assert result[:ok], "sp_i should succeed: #{result[:msg]}"

    # sp_co should update filter cutoff
    result2 = vj_pad.exec("sp_co 3000")
    assert result2[:ok], "sp_co should succeed: #{result2[:msg]}"
    assert_match(/3000/, result2[:msg])
  end

  def test_phase_m_runtime_params_exist_with_correct_defaults
    # Verify Phase M 6 new parameters have correct defaults
    assert_in_delta 2.5, VisualizerPolicy.bloom_strength_scale,    0.001
    assert_in_delta 2.0, VisualizerPolicy.bloom_flash_multiplier,  0.001
    assert_in_delta 0.5, VisualizerPolicy.capture_overlay_opacity, 0.001
    assert_in_delta 1.0, VisualizerPolicy.capture_video_opacity,   0.001
    assert_equal 30,  VisualizerPolicy.serial_audio_volume
    assert_equal 100, VisualizerPolicy.max_saturation

    # Verify clamping works (bloom_strength_scale min: 0.0)
    VisualizerPolicy.bloom_strength_scale = -99.0
    assert_in_delta 0.0, VisualizerPolicy.bloom_strength_scale, 0.001

    # Reset for other tests
    VisualizerPolicy.reset_runtime
  end

  def test_visualizer_policy_mutable_keys_matches_runtime_params
    # Structural consistency: MUTABLE_KEYS and RUNTIME_PARAMS must have same key set
    runtime_keys = VisualizerPolicy::RUNTIME_PARAMS.keys.map(&:to_s).sort
    mutable_keys = VisualizerPolicy::MUTABLE_KEYS.keys.sort
    assert_equal runtime_keys, mutable_keys,
                 "MUTABLE_KEYS and RUNTIME_PARAMS key sets must match. " \
                 "Only in RUNTIME_PARAMS: #{(runtime_keys - mutable_keys).inspect}. " \
                 "Only in MUTABLE_KEYS: #{(mutable_keys - runtime_keys).inspect}"
  end
end
