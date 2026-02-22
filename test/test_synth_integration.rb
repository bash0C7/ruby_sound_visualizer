require_relative 'test_helper'

class TestSynthIntegration < Test::Unit::TestCase
  def setup
    JS.reset_global!
    VisualizerPolicy.reset_runtime
    VJPlugin.reset!
    load File.join(RUBY_SRC_DIR, 'plugins/vj_burst.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_flash.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_shockwave.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_strobe.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_rave.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_serial.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_wordart.rb')
  end

  # --- SynthEngine + SerialAudioSource integration ---

  def test_serial_frequency_frame_triggers_synth_note_on
    synth = SynthEngine.new
    source = SerialAudioSource.new

    # Simulate receiving serial frequency frame
    source.update(440, 50)
    synth.note_on(source.frequency, source.duty)

    assert_equal true, synth.active?
    assert_equal 440, synth.frequency
    assert_equal 50, synth.duty
  end

  def test_serial_zero_frequency_triggers_synth_note_off
    synth = SynthEngine.new
    synth.note_on(440, 50)

    # Simulate zero frequency (hand removed from sensor)
    synth.note_on(0, 0)
    assert_equal false, synth.active?
  end

  def test_serial_mute_duty_zero_stops_synth
    synth = SynthEngine.new
    manager = SerialManager.new
    manager.on_connect(115200)

    # Start: normal frequency frame
    frames = manager.receive_data("<F:440,D:50>\n")
    synth.note_on(frames[0][:frequency], frames[0][:duty])
    assert_equal true, synth.active?

    # Mute: otv.rb toggle_mute sends D:0 with same frequency
    frames = manager.receive_data("<F:440,D:0>\n")
    assert_equal :frequency, frames[0][:type]
    assert_equal 440, frames[0][:frequency]
    assert_equal 0, frames[0][:duty]

    synth.note_on(frames[0][:frequency], frames[0][:duty])
    assert_equal false, synth.active?
  end

  def test_serial_protocol_to_synth_flow
    synth = SynthEngine.new
    manager = SerialManager.new
    manager.on_connect(115200)

    # Simulate receiving raw serial data
    frames = manager.receive_data("<F:880,D:60>\n")
    assert_equal 1, frames.length
    assert_equal :frequency, frames[0][:type]

    # Feed to synth
    synth.note_on(frames[0][:frequency], frames[0][:duty])
    assert_equal 880, synth.frequency
    assert_equal 60, synth.duty
    assert_equal true, synth.active?
  end

  # --- SynthEngine + OscilloscopeRenderer integration ---

  def test_synth_active_sets_oscilloscope_intensity
    synth = SynthEngine.new
    osc = OscilloscopeRenderer.new

    synth.note_on(440, 50)
    # When synth is active, intensity should follow duty
    intensity = synth.duty / 100.0
    osc.set_intensity(intensity)

    assert_in_delta 0.5, osc.intensity, 0.01
  end

  def test_oscilloscope_waveform_update_from_samples
    osc = OscilloscopeRenderer.new

    # Simulate waveform samples (sine wave)
    samples = Array.new(256) { |i| Math.sin(i * 2 * Math::PI / 256) }
    osc.update_waveform(samples)
    osc.push_to_history

    data = osc.render_data
    assert_equal 256, data[:waveform].length
    assert_equal 1, data[:history].length
    assert_equal true, data[:enabled]
  end

  # --- SynthEngine + VJPad integration ---

  def test_vj_pad_synth_waveform_changes_engine
    synth = SynthEngine.new
    osc = OscilloscopeRenderer.new
    pad = VJPad.new(nil, synth_engine: synth, oscilloscope_renderer: osc)

    pad.exec("syn_w square")
    assert_equal :square, synth.waveform

    pad.exec("syn_a 0.2")
    assert_in_delta 0.2, synth.attack, 0.001

    pad.exec("syn_fc 3000")
    assert_in_delta 3000.0, synth.filter_cutoff, 0.1

    pad.exec("syn_fq 12")
    assert_in_delta 12.0, synth.filter_resonance, 0.1
  end

  def test_vj_pad_oscilloscope_toggle
    synth = SynthEngine.new
    osc = OscilloscopeRenderer.new
    pad = VJPad.new(nil, synth_engine: synth, oscilloscope_renderer: osc)

    pad.exec("osc 0")
    assert_equal false, osc.enabled?

    pad.exec("osc 1")
    assert_equal true, osc.enabled?
  end

  # --- SynthEngine consume_update for JSBridge ---

  def test_synth_consume_update_returns_all_params
    synth = SynthEngine.new
    synth.set_waveform(:square)
    synth.set_attack(0.1)
    synth.set_filter_cutoff(5000)
    synth.set_filter_resonance(8)
    synth.note_on(440, 50)

    data = synth.consume_update
    assert_not_nil data
    assert_equal :square, data[:waveform]
    assert_in_delta 0.1, data[:attack], 0.001
    assert_in_delta 5000.0, data[:filter_cutoff], 0.1
    assert_in_delta 8.0, data[:filter_resonance], 0.1
    assert_equal 440, data[:frequency]
    assert_equal 50, data[:duty]
    assert_equal true, data[:active]
  end

  def test_synth_no_update_when_not_pending
    synth = SynthEngine.new
    assert_nil synth.consume_update
  end

  # --- OscilloscopeRenderer render_data for JSBridge ---

  def test_oscilloscope_render_data_has_all_fields
    osc = OscilloscopeRenderer.new
    data = osc.render_data

    assert data.key?(:waveform)
    assert data.key?(:history)
    assert data.key?(:scroll_offset)
    assert data.key?(:intensity)
    assert data.key?(:color)
    assert data.key?(:ribbon_width)
    assert data.key?(:ribbon_height)
    assert data.key?(:z_position)
    assert data.key?(:y_position)
    assert data.key?(:enabled)
  end

  # --- Full serial → synth → oscilloscope pipeline ---

  def test_full_pipeline_serial_to_synth_to_oscilloscope
    manager = SerialManager.new
    manager.on_connect(115200)
    synth = SynthEngine.new
    osc = OscilloscopeRenderer.new

    # Step 1: Receive serial data
    frames = manager.receive_data("<F:660,D:45>\n")
    assert_equal 1, frames.length

    # Step 2: Feed to synth
    frame = frames[0]
    synth.note_on(frame[:frequency], frame[:duty])
    assert_equal true, synth.active?
    assert_equal 660, synth.frequency

    # Step 3: Synth produces update for JS
    synth_data = synth.consume_update
    assert_not_nil synth_data
    assert_equal 660, synth_data[:frequency]

    # Step 4: Oscilloscope gets waveform and renders
    samples = Array.new(256) { |i| Math.sin(i * 2 * Math::PI * 660 / 44100) }
    osc.update_waveform(samples)
    osc.set_intensity(frame[:duty] / 100.0)
    osc.push_to_history
    osc.advance_scroll(16.67)

    render = osc.render_data
    assert_equal true, render[:enabled]
    assert_equal 1, render[:history].length
    assert render[:scroll_offset] > 0
    assert_in_delta 0.45, render[:intensity], 0.01
  end
end
