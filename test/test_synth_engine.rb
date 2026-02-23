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

  def test_initial_gain
    assert_in_delta 0.3, @engine.gain, 0.01
  end

  def test_initial_active_false
    assert_equal false, @engine.active?
  end

  def test_initial_duty_zero
    assert_equal 0, @engine.duty
  end

  def test_initial_voice_count_zero
    assert_equal 0, @engine.voice_count
  end

  def test_initial_max_voices
    assert_equal SynthEngine::DEFAULT_MAX_VOICES, @engine.max_voices
  end

  def test_initial_max_sustain_ms
    assert_equal SynthEngine::DEFAULT_MAX_SUSTAIN_MS, @engine.max_sustain_ms
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

  # --- note_on / note_off (UART RX compatible interface) ---

  def test_note_on_activates
    @engine.note_on(440, 50)
    assert_equal true, @engine.active?
  end

  def test_note_on_sets_duty
    @engine.note_on(440, 50)
    assert_equal 50, @engine.duty
  end

  def test_note_on_clamps_duty_max
    @engine.note_on(440, 150)
    assert_equal 100, @engine.duty
  end

  def test_note_on_clamps_duty_min
    @engine.note_on(440, -10)
    assert_equal 0, @engine.duty
  end

  def test_note_on_with_zero_duty_triggers_note_off
    @engine.note_on(440, 50)
    @engine.note_on(0, 0)
    assert_equal false, @engine.active?
  end

  def test_note_on_nonzero_freq_zero_duty_triggers_note_off
    @engine.note_on(440, 50)
    @engine.note_on(440, 0)
    assert_equal false, @engine.active?
  end

  def test_note_on_allocates_voice
    @engine.note_on(440, 50)
    assert_equal 1, @engine.voice_count
  end

  def test_note_on_same_freq_does_not_duplicate_voice
    @engine.note_on(440, 50)
    @engine.note_on(440, 50)
    assert_equal 1, @engine.voice_count
  end

  def test_note_on_different_freq_releases_previous_voice
    @engine.note_on(440, 50)
    @engine.note_on(880, 50)
    # Previous voice is released (ADSR fade-out); only the new pitch is active
    assert_equal 1, @engine.voice_count
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

  def test_note_on_produces_note_on_voice_event
    @engine.consume_update if @engine.pending_update?
    @engine.note_on(440, 50)
    data = @engine.consume_update
    events = data[:voice_events]
    assert_not_nil events
    assert_equal 1, events.length
    assert_equal :note_on, events[0][:type]
    assert_equal 440, events[0][:freq]
    assert_equal 50, events[0][:duty]
    assert events[0].key?(:voice_id)
  end

  def test_note_off_produces_note_off_voice_event
    @engine.note_on(440, 50)
    @engine.consume_update
    @engine.note_off
    data = @engine.consume_update
    events = data[:voice_events]
    assert_not_nil events
    assert events.any? { |e| e[:type] == :note_off }
  end

  # --- Pitch change releases previous voice ---

  def test_pitch_change_releases_previous_voice
    engine = SynthEngine.new
    engine.consume_update
    engine.note_on(100, 50)
    assert_equal 1, engine.voice_count
    engine.note_on(200, 50)  # new pitch: previous voice released
    assert_equal 1, engine.voice_count
    engine.note_on(300, 50)  # new pitch: previous voice released
    assert_equal 1, engine.voice_count
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

  # --- Voice config ---

  def test_set_max_voices
    @engine.set_max_voices(4)
    assert_equal 4, @engine.max_voices
  end

  def test_set_max_voices_clamps_min
    @engine.set_max_voices(0)
    assert_equal SynthEngine::MAX_VOICES_MIN, @engine.max_voices
  end

  def test_set_max_voices_clamps_max
    @engine.set_max_voices(999)
    assert_equal SynthEngine::MAX_VOICES_MAX, @engine.max_voices
  end

  def test_set_max_sustain_ms
    @engine.set_max_sustain_ms(300)
    assert_equal 300, @engine.max_sustain_ms
  end

  # --- consume_update structure ---

  def test_consume_update_clears_pending
    @engine.note_on(440, 50)
    @engine.consume_update
    assert_equal false, @engine.pending_update?
  end

  def test_consume_update_nil_when_not_pending
    @engine.consume_update if @engine.pending_update?
    assert_nil @engine.consume_update
  end

  def test_consume_update_params_on_waveform_change
    @engine.consume_update if @engine.pending_update?
    @engine.set_waveform(:square)
    data = @engine.consume_update
    assert_not_nil data[:params]
    assert_equal :square, data[:params][:waveform]
    assert data[:params].key?(:attack)
    assert data[:params].key?(:decay)
    assert data[:params].key?(:sustain)
    assert data[:params].key?(:release)
    assert data[:params].key?(:gain)
    assert data[:params].key?(:max_sustain_ms)
  end

  def test_consume_update_voice_events_on_note_on
    @engine.consume_update if @engine.pending_update?
    @engine.note_on(440, 50)
    data = @engine.consume_update
    assert_not_nil data[:voice_events]
    assert_equal 1, data[:voice_events].length
  end

  def test_consume_update_no_filter_keys
    @engine.note_on(440, 50)
    data = @engine.consume_update
    # Filter moved to SynthEffects - must NOT be in SynthEngine output
    refute data.key?(:filter_cutoff)
    refute data.key?(:filter_resonance)
    refute data.key?(:filter_type)
    refute data.key?(:frequency)
    refute data.key?(:active)
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
    assert_match(/sawtooth/, result)
  end

  def test_status_includes_adsr
    result = @engine.status
    assert_match(/A:/, result)
    assert_match(/D:/, result)
    assert_match(/S:/, result)
    assert_match(/R:/, result)
  end

  def test_status_shows_voice_count
    @engine.note_on(440, 50)
    result = @engine.status
    assert_match(/voice/, result)
  end

  # --- Constants ---

  def test_valid_waveforms_constant
    assert_includes SynthEngine::WAVEFORMS, :sine
    assert_includes SynthEngine::WAVEFORMS, :square
    assert_includes SynthEngine::WAVEFORMS, :sawtooth
    assert_includes SynthEngine::WAVEFORMS, :triangle
  end

  def test_no_filter_types_constant
    refute defined?(SynthEngine::FILTER_TYPES)
  end

  # --- Serial receive timeout (auto note_off) ---

  def test_check_timeout_triggers_note_off_after_threshold
    @engine.note_on(440, 50, now_ms: 0.0)
    @engine.check_timeout(current_ms: 201.0, threshold_ms: 200)
    assert_equal false, @engine.active?
  end

  def test_check_timeout_no_effect_before_threshold
    @engine.note_on(440, 50, now_ms: 0.0)
    @engine.check_timeout(current_ms: 199.0, threshold_ms: 200)
    assert_equal true, @engine.active?
  end

  def test_check_timeout_at_exact_threshold_no_effect
    @engine.note_on(440, 50, now_ms: 0.0)
    @engine.check_timeout(current_ms: 200.0, threshold_ms: 200)
    assert_equal true, @engine.active?
  end

  def test_check_timeout_inactive_synth_does_nothing
    assert_equal false, @engine.active?
    @engine.check_timeout(current_ms: 9999.0, threshold_ms: 200)
    assert_equal false, @engine.active?
  end

  def test_check_timeout_without_note_on_does_nothing
    @engine.check_timeout(current_ms: 9999.0, threshold_ms: 200)
    assert_equal false, @engine.active?
  end

  def test_check_timeout_marks_pending_on_note_off
    @engine.note_on(440, 50, now_ms: 0.0)
    @engine.consume_update
    @engine.check_timeout(current_ms: 201.0, threshold_ms: 200)
    assert_equal true, @engine.pending_update?
  end

  def test_check_timeout_default_threshold
    assert_equal SerialProtocol::RECEIVE_TIMEOUT_MS, 200
  end

  def test_note_on_refreshes_timeout
    @engine.note_on(440, 50, now_ms: 0.0)
    @engine.note_on(440, 50, now_ms: 150.0)
    @engine.check_timeout(current_ms: 250.0, threshold_ms: 200)
    assert_equal true, @engine.active?
  end

  def test_note_on_different_freq_refreshes_timeout
    @engine.note_on(440, 50, now_ms: 0.0)
    @engine.note_on(880, 50, now_ms: 150.0)
    @engine.check_timeout(current_ms: 250.0, threshold_ms: 200)
    assert_equal true, @engine.active?
  end
end
