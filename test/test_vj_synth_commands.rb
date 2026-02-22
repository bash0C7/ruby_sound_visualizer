require_relative 'test_helper'

class TestVJSynthCommands < Test::Unit::TestCase
  def setup
    VJPlugin.reset!
    # Re-register plugins after reset
    load File.join(RUBY_SRC_DIR, 'plugins/vj_burst.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_flash.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_shockwave.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_strobe.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_rave.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_serial.rb')
    load File.join(RUBY_SRC_DIR, 'plugins/vj_wordart.rb')

    @synth_engine = SynthEngine.new
    @oscilloscope_renderer = OscilloscopeRenderer.new
    @pad = VJPad.new(nil,
                     synth_engine: @synth_engine,
                     oscilloscope_renderer: @oscilloscope_renderer)
  end

  # --- Synth not available ---

  def test_syn_w_not_available
    pad = VJPad.new
    result = pad.exec("syn_w")
    assert_equal "synth: not available", result[:msg]
  end

  # --- Waveform ---

  def test_syn_w_get
    result = @pad.exec("syn_w")
    assert_equal "synth wave: sawtooth", result[:msg]
  end

  def test_syn_w_set_sine
    result = @pad.exec("syn_w sine")
    assert_equal "synth wave: sine", result[:msg]
    assert_equal :sine, @synth_engine.waveform
  end

  def test_syn_w_set_square
    result = @pad.exec("syn_w square")
    assert_equal "synth wave: square", result[:msg]
  end

  def test_syn_w_set_triangle
    result = @pad.exec("syn_w triangle")
    assert_equal "synth wave: triangle", result[:msg]
  end

  # --- Attack ---

  def test_syn_a_get
    result = @pad.exec("syn_a")
    assert_equal "synth attack: 0.01s", result[:msg]
  end

  def test_syn_a_set
    result = @pad.exec("syn_a 0.5")
    assert_equal "synth attack: 0.5s", result[:msg]
    assert_in_delta 0.5, @synth_engine.attack, 0.001
  end

  # --- Decay ---

  def test_syn_d_get
    result = @pad.exec("syn_d")
    assert_equal "synth decay: 0.3s", result[:msg]
  end

  def test_syn_d_set
    result = @pad.exec("syn_d 1.0")
    assert_equal "synth decay: 1.0s", result[:msg]
    assert_in_delta 1.0, @synth_engine.decay, 0.001
  end

  # --- Sustain ---

  def test_syn_s_get
    result = @pad.exec("syn_s")
    assert_equal "synth sustain: 0.6", result[:msg]
  end

  def test_syn_s_set
    result = @pad.exec("syn_s 0.8")
    assert_equal "synth sustain: 0.8", result[:msg]
    assert_in_delta 0.8, @synth_engine.sustain, 0.001
  end

  # --- Release ---

  def test_syn_r_get
    result = @pad.exec("syn_r")
    assert_equal "synth release: 0.3s", result[:msg]
  end

  def test_syn_r_set
    result = @pad.exec("syn_r 1.5")
    assert_equal "synth release: 1.5s", result[:msg]
    assert_in_delta 1.5, @synth_engine.release, 0.001
  end

  # --- Filter cutoff ---

  def test_syn_fc_get
    result = @pad.exec("syn_fc")
    assert_equal "synth cutoff: 2000Hz", result[:msg]
  end

  def test_syn_fc_set
    result = @pad.exec("syn_fc 5000")
    assert_equal "synth cutoff: 5000Hz", result[:msg]
    assert_in_delta 5000.0, @synth_engine.filter_cutoff, 0.1
  end

  # --- Filter resonance ---

  def test_syn_fq_get
    result = @pad.exec("syn_fq")
    assert_equal "synth Q: 1.0", result[:msg]
  end

  def test_syn_fq_set
    result = @pad.exec("syn_fq 10")
    assert_equal "synth Q: 10.0", result[:msg]
    assert_in_delta 10.0, @synth_engine.filter_resonance, 0.1
  end

  # --- Filter type ---

  def test_syn_ft_get
    result = @pad.exec("syn_ft")
    assert_equal "synth filter: lowpass", result[:msg]
  end

  def test_syn_ft_set_highpass
    result = @pad.exec("syn_ft highpass")
    assert_equal "synth filter: highpass", result[:msg]
    assert_equal :highpass, @synth_engine.filter_type
  end

  def test_syn_ft_set_bandpass
    result = @pad.exec("syn_ft bandpass")
    assert_equal "synth filter: bandpass", result[:msg]
  end

  # --- Gain ---

  def test_syn_g_get
    result = @pad.exec("syn_g")
    assert_equal "synth gain: 30%", result[:msg]
  end

  def test_syn_g_set
    result = @pad.exec("syn_g 80")
    assert_equal "synth gain: 80%", result[:msg]
    assert_in_delta 0.8, @synth_engine.gain, 0.01
  end

  # --- Synth info ---

  def test_syn_i
    result = @pad.exec("syn_i")
    assert_match(/synth:/, result[:msg])
    assert_match(/sawtooth/, result[:msg])
  end

  # --- Oscilloscope ---

  def test_osc_get
    result = @pad.exec("osc")
    assert_equal "oscilloscope: on", result[:msg]
  end

  def test_osc_disable
    result = @pad.exec("osc 0")
    assert_equal "oscilloscope: off", result[:msg]
    assert_equal false, @oscilloscope_renderer.enabled?
  end

  def test_osc_enable
    @oscilloscope_renderer.disable
    result = @pad.exec("osc 1")
    assert_equal "oscilloscope: on", result[:msg]
    assert_equal true, @oscilloscope_renderer.enabled?
  end

  def test_osc_not_available
    pad = VJPad.new
    result = pad.exec("osc")
    assert_equal "oscilloscope: not available", result[:msg]
  end

  # --- Oscilloscope scroll speed ---

  def test_osc_sp_get
    result = @pad.exec("osc_sp")
    assert_equal "osc speed: 2.0", result[:msg]
  end

  def test_osc_sp_set
    result = @pad.exec("osc_sp 5.0")
    assert_equal "osc speed: 5.0", result[:msg]
    assert_in_delta 5.0, @oscilloscope_renderer.scroll_speed, 0.01
  end
end
