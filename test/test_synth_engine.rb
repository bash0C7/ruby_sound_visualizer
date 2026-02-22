require_relative 'test_helper'

class TestSynthEngine < Test::Unit::TestCase
  def setup
    @engine = SynthEngine.new
  end

  # --- Initial state ---

  def test_initial_waveform_is_sawtooth
    assert_equal :sawtooth, @engine.waveform
  end

  def test_initial_attack
    assert_in_delta 0.01, @engine.attack, 0.001
  end

  def test_initial_decay
    assert_in_delta 0.3, @engine.decay, 0.001
  end

  def test_initial_sustain
    assert_in_delta 0.6, @engine.sustain, 0.001
  end

  def test_initial_release
    assert_in_delta 0.3, @engine.release, 0.001
  end

  def test_initial_filter_cutoff
    assert_in_delta 2000.0, @engine.filter_cutoff, 0.1
  end

  def test_initial_filter_resonance
    assert_in_delta 1.0, @engine.filter_resonance, 0.1
  end

  def test_initial_filter_type
    assert_equal :lowpass, @engine.filter_type
  end

  def test_initial_frequency_zero
    assert_equal 0, @engine.frequency
  end

  def test_initial_duty_zero
    assert_equal 0, @engine.duty
  end

  def test_initial_gain
    assert_in_delta 0.3, @engine.gain, 0.01
  end

  def test_initial_active_false
    assert_equal false, @engine.active?
  end

  # --- Waveform ---

  def test_set_waveform_sine
    @engine.set_waveform(:sine)
    assert_equal :sine, @engine.waveform
  end

  def test_set_waveform_square
    @engine.set_waveform(:square)
    assert_equal :square, @engine.waveform
  end

  def test_set_waveform_sawtooth
    @engine.set_waveform(:sawtooth)
    assert_equal :sawtooth, @engine.waveform
  end

  def test_set_waveform_triangle
    @engine.set_waveform(:triangle)
    assert_equal :triangle, @engine.waveform
  end

  def test_set_waveform_invalid_raises
    assert_raise(ArgumentError) { @engine.set_waveform(:noise) }
  end

  def test_set_waveform_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.set_waveform(:sine)
    assert_equal true, @engine.pending_update?
  end

  def test_set_waveform_by_string
    @engine.set_waveform("square")
    assert_equal :square, @engine.waveform
  end

  # --- ADSR Envelope ---

  def test_set_attack
    @engine.set_attack(0.5)
    assert_in_delta 0.5, @engine.attack, 0.001
  end

  def test_set_attack_clamps_min
    @engine.set_attack(-1.0)
    assert_in_delta 0.001, @engine.attack, 0.0001
  end

  def test_set_attack_clamps_max
    @engine.set_attack(10.0)
    assert_in_delta 5.0, @engine.attack, 0.001
  end

  def test_set_attack_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.set_attack(0.5)
    assert_equal true, @engine.pending_update?
  end

  def test_set_decay
    @engine.set_decay(1.0)
    assert_in_delta 1.0, @engine.decay, 0.001
  end

  def test_set_decay_clamps_min
    @engine.set_decay(-1.0)
    assert_in_delta 0.001, @engine.decay, 0.0001
  end

  def test_set_decay_clamps_max
    @engine.set_decay(10.0)
    assert_in_delta 5.0, @engine.decay, 0.001
  end

  def test_set_decay_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.set_decay(1.0)
    assert_equal true, @engine.pending_update?
  end

  def test_set_sustain
    @engine.set_sustain(0.8)
    assert_in_delta 0.8, @engine.sustain, 0.001
  end

  def test_set_sustain_clamps_min
    @engine.set_sustain(-0.5)
    assert_in_delta 0.0, @engine.sustain, 0.001
  end

  def test_set_sustain_clamps_max
    @engine.set_sustain(1.5)
    assert_in_delta 1.0, @engine.sustain, 0.001
  end

  def test_set_sustain_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.set_sustain(0.8)
    assert_equal true, @engine.pending_update?
  end

  def test_set_release
    @engine.set_release(1.5)
    assert_in_delta 1.5, @engine.release, 0.001
  end

  def test_set_release_clamps_min
    @engine.set_release(-1.0)
    assert_in_delta 0.001, @engine.release, 0.0001
  end

  def test_set_release_clamps_max
    @engine.set_release(10.0)
    assert_in_delta 5.0, @engine.release, 0.001
  end

  def test_set_release_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.set_release(1.5)
    assert_equal true, @engine.pending_update?
  end

  # --- Filter ---

  def test_set_filter_cutoff
    @engine.set_filter_cutoff(5000.0)
    assert_in_delta 5000.0, @engine.filter_cutoff, 0.1
  end

  def test_set_filter_cutoff_clamps_min
    @engine.set_filter_cutoff(5.0)
    assert_in_delta 20.0, @engine.filter_cutoff, 0.1
  end

  def test_set_filter_cutoff_clamps_max
    @engine.set_filter_cutoff(25000.0)
    assert_in_delta 20000.0, @engine.filter_cutoff, 0.1
  end

  def test_set_filter_cutoff_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.set_filter_cutoff(5000.0)
    assert_equal true, @engine.pending_update?
  end

  def test_set_filter_resonance
    @engine.set_filter_resonance(10.0)
    assert_in_delta 10.0, @engine.filter_resonance, 0.1
  end

  def test_set_filter_resonance_clamps_min
    @engine.set_filter_resonance(-1.0)
    assert_in_delta 0.0, @engine.filter_resonance, 0.1
  end

  def test_set_filter_resonance_clamps_max
    @engine.set_filter_resonance(35.0)
    assert_in_delta 30.0, @engine.filter_resonance, 0.1
  end

  def test_set_filter_resonance_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.set_filter_resonance(10.0)
    assert_equal true, @engine.pending_update?
  end

  def test_set_filter_type_lowpass
    @engine.set_filter_type(:lowpass)
    assert_equal :lowpass, @engine.filter_type
  end

  def test_set_filter_type_highpass
    @engine.set_filter_type(:highpass)
    assert_equal :highpass, @engine.filter_type
  end

  def test_set_filter_type_bandpass
    @engine.set_filter_type(:bandpass)
    assert_equal :bandpass, @engine.filter_type
  end

  def test_set_filter_type_invalid_raises
    assert_raise(ArgumentError) { @engine.set_filter_type(:notch) }
  end

  def test_set_filter_type_by_string
    @engine.set_filter_type("highpass")
    assert_equal :highpass, @engine.filter_type
  end

  def test_set_filter_type_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.set_filter_type(:highpass)
    assert_equal true, @engine.pending_update?
  end

  # --- Frequency/Duty from serial ---

  def test_note_on_sets_frequency_and_duty
    @engine.note_on(440, 50)
    assert_equal 440, @engine.frequency
    assert_equal 50, @engine.duty
  end

  def test_note_on_activates
    @engine.note_on(440, 50)
    assert_equal true, @engine.active?
  end

  def test_note_on_clamps_frequency_max
    @engine.note_on(25000, 50)
    assert_equal 20000, @engine.frequency
  end

  def test_note_on_clamps_frequency_min
    @engine.note_on(-100, 50)
    assert_equal 0, @engine.frequency
  end

  def test_note_on_clamps_duty_max
    @engine.note_on(440, 150)
    assert_equal 100, @engine.duty
  end

  def test_note_on_clamps_duty_min
    @engine.note_on(440, -10)
    assert_equal 0, @engine.duty
  end

  def test_note_on_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.note_on(440, 50)
    assert_equal true, @engine.pending_update?
  end

  def test_note_off_deactivates
    @engine.note_on(440, 50)
    @engine.note_off
    assert_equal false, @engine.active?
  end

  def test_note_off_marks_pending
    @engine.note_on(440, 50)
    @engine.consume_update
    @engine.note_off
    assert_equal true, @engine.pending_update?
  end

  def test_note_on_with_zero_duty_triggers_note_off
    @engine.note_on(440, 50)
    @engine.note_on(0, 0)
    assert_equal false, @engine.active?
  end

  # --- Gain ---

  def test_set_gain
    @engine.set_gain(0.8)
    assert_in_delta 0.8, @engine.gain, 0.01
  end

  def test_set_gain_clamps_min
    @engine.set_gain(-0.5)
    assert_in_delta 0.0, @engine.gain, 0.01
  end

  def test_set_gain_clamps_max
    @engine.set_gain(1.5)
    assert_in_delta 1.0, @engine.gain, 0.01
  end

  def test_set_gain_marks_pending
    @engine.consume_update if @engine.pending_update?
    @engine.set_gain(0.5)
    assert_equal true, @engine.pending_update?
  end

  # --- Pending update / consume ---

  def test_consume_update_clears_pending
    @engine.note_on(440, 50)
    @engine.consume_update
    assert_equal false, @engine.pending_update?
  end

  def test_consume_update_returns_full_state
    @engine.set_waveform(:square)
    @engine.set_attack(0.1)
    @engine.set_decay(0.5)
    @engine.set_sustain(0.7)
    @engine.set_release(0.4)
    @engine.set_filter_cutoff(3000.0)
    @engine.set_filter_resonance(8.0)
    @engine.set_filter_type(:highpass)
    @engine.note_on(880, 60)
    @engine.set_gain(0.5)

    data = @engine.consume_update
    assert_equal :square, data[:waveform]
    assert_in_delta 0.1, data[:attack], 0.001
    assert_in_delta 0.5, data[:decay], 0.001
    assert_in_delta 0.7, data[:sustain], 0.001
    assert_in_delta 0.4, data[:release], 0.001
    assert_in_delta 3000.0, data[:filter_cutoff], 0.1
    assert_in_delta 8.0, data[:filter_resonance], 0.1
    assert_equal :highpass, data[:filter_type]
    assert_equal 880, data[:frequency]
    assert_equal 60, data[:duty]
    assert_equal true, data[:active]
    assert_in_delta 0.5, data[:gain], 0.01
  end

  def test_consume_update_nil_when_not_pending
    @engine.consume_update if @engine.pending_update?
    assert_nil @engine.consume_update
  end

  # --- Status ---

  def test_status_when_inactive
    result = @engine.status
    assert_match(/off/, result)
    assert_match(/sawtooth/, result)
  end

  def test_status_when_active
    @engine.note_on(440, 50)
    result = @engine.status
    assert_match(/on/, result)
    assert_match(/440/, result)
    assert_match(/sawtooth/, result)
  end

  def test_status_includes_adsr
    result = @engine.status
    assert_match(/A:/, result)
    assert_match(/D:/, result)
    assert_match(/S:/, result)
    assert_match(/R:/, result)
  end

  def test_status_includes_filter
    result = @engine.status
    assert_match(/cutoff/, result)
    assert_match(/Q/, result)
  end

  # --- Constants ---

  def test_valid_waveforms_constant
    assert_includes SynthEngine::WAVEFORMS, :sine
    assert_includes SynthEngine::WAVEFORMS, :square
    assert_includes SynthEngine::WAVEFORMS, :sawtooth
    assert_includes SynthEngine::WAVEFORMS, :triangle
  end

  def test_valid_filter_types_constant
    assert_includes SynthEngine::FILTER_TYPES, :lowpass
    assert_includes SynthEngine::FILTER_TYPES, :highpass
    assert_includes SynthEngine::FILTER_TYPES, :bandpass
  end
end
