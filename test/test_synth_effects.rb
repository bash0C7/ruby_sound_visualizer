require_relative 'test_helper'

class TestSynthEffects < Test::Unit::TestCase
  def setup
    @fx = SynthEffects.new
  end

  # --- Presets ---

  def test_through_preset_is_frozen
    assert SynthEffects::THROUGH_PRESET.frozen?
  end

  def test_hardcore_preset_is_frozen
    assert SynthEffects::HARDCORE_PRESET.frozen?
  end

  def test_default_preset_is_through
    assert_equal SynthEffects::THROUGH_PRESET, SynthEffects::DEFAULT_PRESET
  end

  def test_initial_state_is_through_preset
    p = SynthEffects::THROUGH_PRESET
    assert_equal p[:distortion],    @fx.distortion
    assert_equal p[:filter_type],   @fx.filter_type
    assert_equal p[:filter_cutoff], @fx.filter_cutoff
    assert_equal p[:filter_q],      @fx.filter_q
    assert_equal p[:delay_time],    @fx.delay_time
    assert_equal p[:delay_feedback], @fx.delay_feedback
    assert_equal p[:delay_wet],     @fx.delay_wet
    assert_equal p[:reverb_size],   @fx.reverb_size
    assert_equal p[:reverb_decay],  @fx.reverb_decay
    assert_equal p[:reverb_wet],    @fx.reverb_wet
    assert_equal p[:comp_threshold], @fx.comp_threshold
    assert_equal p[:comp_ratio],    @fx.comp_ratio
    assert_equal p[:comp_attack],   @fx.comp_attack
    assert_equal p[:comp_release],  @fx.comp_release
  end

  def test_through_preset_distortion_zero
    assert_equal 0, SynthEffects::THROUGH_PRESET[:distortion]
  end

  def test_through_preset_filter_allpass
    assert_equal 'allpass', SynthEffects::THROUGH_PRESET[:filter_type]
  end

  def test_through_preset_delay_wet_zero
    assert_equal 0.0, SynthEffects::THROUGH_PRESET[:delay_wet]
  end

  def test_through_preset_reverb_wet_zero
    assert_equal 0.0, SynthEffects::THROUGH_PRESET[:reverb_wet]
  end

  def test_through_preset_comp_ratio_one
    assert_equal 1.0, SynthEffects::THROUGH_PRESET[:comp_ratio]
  end

  def test_hardcore_preset_heavy_distortion
    assert SynthEffects::HARDCORE_PRESET[:distortion] >= 200
  end

  def test_hardcore_preset_lowpass_filter
    assert_equal 'lowpass', SynthEffects::HARDCORE_PRESET[:filter_type]
  end

  def test_hardcore_preset_high_resonance
    assert SynthEffects::HARDCORE_PRESET[:filter_q] >= 10
  end

  def test_hardcore_preset_delay_wet_nonzero
    assert SynthEffects::HARDCORE_PRESET[:delay_wet] > 0
  end

  def test_hardcore_preset_reverb_wet_nonzero
    assert SynthEffects::HARDCORE_PRESET[:reverb_wet] > 0
  end

  def test_hardcore_preset_heavy_compression
    assert SynthEffects::HARDCORE_PRESET[:comp_ratio] >= 8
  end

  # --- apply_preset ---

  def test_apply_hardcore_preset
    @fx.apply_preset(SynthEffects::HARDCORE_PRESET)
    assert_equal SynthEffects::HARDCORE_PRESET[:distortion], @fx.distortion
    assert_equal SynthEffects::HARDCORE_PRESET[:filter_type], @fx.filter_type
    assert_in_delta SynthEffects::HARDCORE_PRESET[:filter_cutoff], @fx.filter_cutoff, 0.1
  end

  def test_apply_preset_marks_pending
    @fx.consume_update if @fx.pending_update?
    @fx.apply_preset(SynthEffects::HARDCORE_PRESET)
    assert_equal true, @fx.pending_update?
  end

  def test_apply_through_resets_to_bypass
    @fx.apply_preset(SynthEffects::HARDCORE_PRESET)
    @fx.apply_preset(SynthEffects::THROUGH_PRESET)
    assert_equal 0, @fx.distortion
    assert_equal 0.0, @fx.reverb_wet
  end

  # --- Distortion ---

  def test_set_distortion
    @fx.set_distortion(150)
    assert_equal 150, @fx.distortion
  end

  def test_set_distortion_clamps_min
    @fx.set_distortion(-10)
    assert_equal 0, @fx.distortion
  end

  def test_set_distortion_clamps_max
    @fx.set_distortion(9999)
    assert_equal SynthEffects::DIST_MAX, @fx.distortion
  end

  def test_set_distortion_marks_pending
    @fx.consume_update if @fx.pending_update?
    @fx.set_distortion(100)
    assert_equal true, @fx.pending_update?
  end

  # --- Filter ---

  def test_set_filter_cutoff
    @fx.set_filter_cutoff(3000.0)
    assert_in_delta 3000.0, @fx.filter_cutoff, 0.1
  end

  def test_set_filter_cutoff_clamps_min
    @fx.set_filter_cutoff(1.0)
    assert_in_delta SynthEffects::CUTOFF_MIN, @fx.filter_cutoff, 0.1
  end

  def test_set_filter_cutoff_clamps_max
    @fx.set_filter_cutoff(99999.0)
    assert_in_delta SynthEffects::CUTOFF_MAX, @fx.filter_cutoff, 0.1
  end

  def test_set_filter_q
    @fx.set_filter_q(8.0)
    assert_in_delta 8.0, @fx.filter_q, 0.01
  end

  def test_set_filter_q_clamps_min
    @fx.set_filter_q(0.0)
    assert_in_delta SynthEffects::Q_MIN, @fx.filter_q, 0.01
  end

  def test_set_filter_q_clamps_max
    @fx.set_filter_q(100.0)
    assert_in_delta SynthEffects::Q_MAX, @fx.filter_q, 0.01
  end

  def test_set_filter_type_lowpass
    @fx.set_filter_type('lowpass')
    assert_equal 'lowpass', @fx.filter_type
  end

  def test_set_filter_type_highpass
    @fx.set_filter_type('highpass')
    assert_equal 'highpass', @fx.filter_type
  end

  def test_set_filter_type_bandpass
    @fx.set_filter_type('bandpass')
    assert_equal 'bandpass', @fx.filter_type
  end

  def test_set_filter_type_allpass
    @fx.set_filter_type('allpass')
    assert_equal 'allpass', @fx.filter_type
  end

  def test_set_filter_type_notch
    @fx.set_filter_type('notch')
    assert_equal 'notch', @fx.filter_type
  end

  def test_set_filter_type_invalid_raises
    assert_raise(ArgumentError) { @fx.set_filter_type('unknown') }
  end

  def test_set_filter_type_marks_pending
    @fx.consume_update if @fx.pending_update?
    @fx.set_filter_type('lowpass')
    assert_equal true, @fx.pending_update?
  end

  # --- Delay ---

  def test_set_delay_time
    @fx.set_delay_time(0.25)
    assert_in_delta 0.25, @fx.delay_time, 0.001
  end

  def test_set_delay_time_clamps_min
    @fx.set_delay_time(-1.0)
    assert_in_delta 0.0, @fx.delay_time, 0.001
  end

  def test_set_delay_time_clamps_max
    @fx.set_delay_time(99.0)
    assert_in_delta SynthEffects::DELAY_TIME_MAX, @fx.delay_time, 0.001
  end

  def test_set_delay_feedback
    @fx.set_delay_feedback(0.5)
    assert_in_delta 0.5, @fx.delay_feedback, 0.001
  end

  def test_set_delay_feedback_clamps_max
    @fx.set_delay_feedback(1.0)
    assert_in_delta SynthEffects::DELAY_FB_MAX, @fx.delay_feedback, 0.001
  end

  def test_set_delay_wet
    @fx.set_delay_wet(0.4)
    assert_in_delta 0.4, @fx.delay_wet, 0.001
  end

  def test_set_delay_wet_clamps
    @fx.set_delay_wet(1.5)
    assert_in_delta 1.0, @fx.delay_wet, 0.001
  end

  def test_set_delay_marks_pending
    @fx.consume_update if @fx.pending_update?
    @fx.set_delay_time(0.125)
    assert_equal true, @fx.pending_update?
  end

  # --- Reverb ---

  def test_set_reverb_size
    @fx.set_reverb_size(2.0)
    assert_in_delta 2.0, @fx.reverb_size, 0.01
  end

  def test_set_reverb_size_clamps_min
    @fx.set_reverb_size(0.0)
    assert_in_delta SynthEffects::REVERB_SIZE_MIN, @fx.reverb_size, 0.01
  end

  def test_set_reverb_decay
    @fx.set_reverb_decay(4.0)
    assert_in_delta 4.0, @fx.reverb_decay, 0.01
  end

  def test_set_reverb_wet
    @fx.set_reverb_wet(0.3)
    assert_in_delta 0.3, @fx.reverb_wet, 0.001
  end

  def test_set_reverb_wet_clamps
    @fx.set_reverb_wet(-0.5)
    assert_in_delta 0.0, @fx.reverb_wet, 0.001
  end

  def test_set_reverb_marks_pending
    @fx.consume_update if @fx.pending_update?
    @fx.set_reverb_wet(0.2)
    assert_equal true, @fx.pending_update?
  end

  # --- Compressor ---

  def test_set_comp_threshold
    @fx.set_comp_threshold(-18.0)
    assert_in_delta(-18.0, @fx.comp_threshold, 0.01)
  end

  def test_set_comp_threshold_clamps_min
    @fx.set_comp_threshold(-100.0)
    assert_in_delta SynthEffects::COMP_THRESHOLD_MIN, @fx.comp_threshold, 0.01
  end

  def test_set_comp_ratio
    @fx.set_comp_ratio(10.0)
    assert_in_delta 10.0, @fx.comp_ratio, 0.01
  end

  def test_set_comp_ratio_clamps_min
    @fx.set_comp_ratio(0.5)
    assert_in_delta SynthEffects::COMP_RATIO_MIN, @fx.comp_ratio, 0.01
  end

  def test_set_comp_ratio_clamps_max
    @fx.set_comp_ratio(99.0)
    assert_in_delta SynthEffects::COMP_RATIO_MAX, @fx.comp_ratio, 0.01
  end

  # --- pending_update / consume_update ---

  def test_initial_pending_false
    fx = SynthEffects.new
    fx.consume_update  # drain initial pending from apply_preset in initialize
    assert_equal false, fx.pending_update?
  end

  def test_consume_update_clears_pending
    @fx.set_distortion(100)
    @fx.consume_update
    assert_equal false, @fx.pending_update?
  end

  def test_consume_update_returns_hash
    @fx.set_distortion(100)
    result = @fx.consume_update
    assert_not_nil result
    assert result.key?(:distortion)
    assert result.key?(:filter_type)
    assert result.key?(:filter_cutoff)
    assert result.key?(:filter_q)
    assert result.key?(:delay_time)
    assert result.key?(:delay_feedback)
    assert result.key?(:delay_wet)
    assert result.key?(:reverb_size)
    assert result.key?(:reverb_decay)
    assert result.key?(:reverb_wet)
    assert result.key?(:comp_threshold)
    assert result.key?(:comp_ratio)
    assert result.key?(:comp_attack)
    assert result.key?(:comp_release)
  end

  def test_consume_update_nil_when_not_pending
    fx = SynthEffects.new
    fx.consume_update
    assert_nil fx.consume_update
  end

  def test_consume_update_returns_current_values
    @fx.set_distortion(200)
    @fx.set_filter_cutoff(4000)
    @fx.set_reverb_wet(0.25)
    data = @fx.consume_update
    assert_equal 200, data[:distortion]
    assert_in_delta 4000, data[:filter_cutoff], 0.1
    assert_in_delta 0.25, data[:reverb_wet], 0.001
  end

  # --- to_h ---

  def test_to_h_returns_all_keys
    h = @fx.to_h
    assert h.key?(:distortion)
    assert h.key?(:filter_type)
    assert h.key?(:filter_cutoff)
    assert h.key?(:filter_q)
    assert h.key?(:delay_time)
    assert h.key?(:delay_feedback)
    assert h.key?(:delay_wet)
    assert h.key?(:reverb_size)
    assert h.key?(:reverb_decay)
    assert h.key?(:reverb_wet)
    assert h.key?(:comp_threshold)
    assert h.key?(:comp_ratio)
    assert h.key?(:comp_attack)
    assert h.key?(:comp_release)
  end

  # --- status ---

  def test_status_includes_distortion
    result = @fx.status
    assert_match(/dist/, result)
  end

  def test_status_includes_filter
    result = @fx.status
    assert_match(/filt/, result)
  end

  def test_status_includes_delay
    result = @fx.status
    assert_match(/dly/, result)
  end

  def test_status_includes_reverb
    result = @fx.status
    assert_match(/rev/, result)
  end
end
