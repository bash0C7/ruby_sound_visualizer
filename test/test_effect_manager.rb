require_relative 'test_helper'

class TestEffectManagerImpulseAccessors < Test::Unit::TestCase
  def setup
    JS.reset_global!
    @manager = EffectManager.new
  end

  def test_impulse_accessors_exist
    assert_respond_to @manager, :impulse_overall
    assert_respond_to @manager, :impulse_bass
    assert_respond_to @manager, :impulse_mid
    assert_respond_to @manager, :impulse_high
  end

  def test_impulse_values_start_at_zero
    assert_equal 0.0, @manager.impulse_overall
    assert_equal 0.0, @manager.impulse_bass
    assert_equal 0.0, @manager.impulse_mid
    assert_equal 0.0, @manager.impulse_high
  end

  def test_impulse_fires_on_bass_beat
    analysis = make_analysis(beat_bass: true)
    @manager.update(analysis)

    assert_operator @manager.impulse_bass, :>, 0.0
    assert_operator @manager.impulse_overall, :>, 0.0
  end

  def test_impulse_decays_over_frames
    analysis_beat = make_analysis(beat_bass: true)
    @manager.update(analysis_beat)
    impulse_after_beat = @manager.impulse_bass

    analysis_quiet = make_analysis
    @manager.update(analysis_quiet)
    impulse_after_decay = @manager.impulse_bass

    assert_operator impulse_after_decay, :<, impulse_after_beat,
      "Impulse should decay after beat ends"
  end

  # --- inject_impulse (for VJPad burst) ---

  def test_inject_impulse_sets_values
    @manager.inject_impulse(bass: 1.0, mid: 0.5, high: 0.0, overall: 0.8)
    assert_in_delta 1.0, @manager.impulse_bass, 0.001
    assert_in_delta 0.5, @manager.impulse_mid, 0.001
    assert_in_delta 0.0, @manager.impulse_high, 0.001
    assert_in_delta 0.8, @manager.impulse_overall, 0.001
  end

  def test_inject_impulse_takes_max_with_existing
    analysis_beat = make_analysis(beat_bass: true)
    @manager.update(analysis_beat)
    # impulse_bass should be > 0 from beat decay
    existing = @manager.impulse_bass
    @manager.inject_impulse(bass: 0.5)
    # Should take whichever is greater
    assert_in_delta [existing, 0.5].max, @manager.impulse_bass, 0.001
  end

  # --- inject_bloom_flash (for VJPad flash) ---

  def test_inject_bloom_flash_sets_flash_impulse
    @manager.inject_bloom_flash(2.0)
    assert_in_delta 2.0, @manager.bloom_flash, 0.001
  end

  def test_bloom_flash_starts_at_zero
    assert_in_delta 0.0, @manager.bloom_flash, 0.001
  end

  def test_bloom_flash_decays_after_update
    @manager.inject_bloom_flash(1.0)
    analysis = make_analysis
    @manager.update(analysis)
    assert_operator @manager.bloom_flash, :<, 1.0
  end

  private

  def make_analysis(bass: 0.0, mid: 0.0, high: 0.0, energy: 0.0,
                    beat_bass: false, beat_mid: false, beat_high: false)
    {
      bass: bass,
      mid: mid,
      high: high,
      overall_energy: energy,
      dominant_frequency: 0,
      beat: {
        overall: beat_bass,
        bass: beat_bass,
        mid: beat_mid,
        high: beat_high
      },
      bands: { bass: [], mid: [], high: [] }
    }
  end
end
