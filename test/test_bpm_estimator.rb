require_relative 'test_helper'

class TestBPMEstimator < Test::Unit::TestCase
  def setup
    @estimator = BPMEstimator.new
  end

  def test_initial_bpm_is_zero
    assert_equal 0, @estimator.estimated_bpm
  end

  def test_initial_frame_count_is_zero
    assert_equal 0, @estimator.frame_count
  end

  def test_tick_increments_frame_count
    @estimator.tick
    assert_equal 1, @estimator.frame_count
    @estimator.tick
    assert_equal 2, @estimator.frame_count
  end

  def test_record_beat_with_insufficient_data
    @estimator.record_beat(1, fps: 30.0)
    assert_equal 0, @estimator.estimated_bpm
  end

  def test_record_beat_calculates_bpm
    # Simulate beats every 15 frames at 30fps = 120 BPM
    @estimator.record_beat(0, fps: 30.0)
    @estimator.record_beat(15, fps: 30.0)
    @estimator.record_beat(30, fps: 30.0)
    bpm = @estimator.estimated_bpm
    assert_equal 120, bpm
  end

  def test_bpm_clamp_too_low
    # Beats too far apart = very low BPM (below 40)
    @estimator.record_beat(0, fps: 30.0)
    @estimator.record_beat(100, fps: 30.0)
    @estimator.record_beat(200, fps: 30.0)
    assert_equal 0, @estimator.estimated_bpm
  end

  def test_bpm_clamp_too_high
    # Beats too close together = very high BPM (above 240)
    @estimator.record_beat(0, fps: 30.0)
    @estimator.record_beat(1, fps: 30.0)
    @estimator.record_beat(2, fps: 30.0)
    assert_equal 0, @estimator.estimated_bpm
  end

  def test_ring_buffer_keeps_last_16
    20.times do |i|
      @estimator.record_beat(i * 15, fps: 30.0)
    end
    # Should still have valid BPM (ring buffer doesn't overflow)
    assert @estimator.estimated_bpm > 0
  end

  def test_bpm_120_at_60fps
    # Simulate 120 BPM at 60fps: beat every 30 frames
    @estimator.record_beat(0, fps: 60.0)
    @estimator.record_beat(30, fps: 60.0)
    @estimator.record_beat(60, fps: 60.0)
    assert_equal 120, @estimator.estimated_bpm
  end

  def test_needs_at_least_3_beats
    @estimator.record_beat(0, fps: 30.0)
    @estimator.record_beat(15, fps: 30.0)
    assert_equal 0, @estimator.estimated_bpm

    @estimator.record_beat(30, fps: 30.0)
    assert_equal 120, @estimator.estimated_bpm
  end

  def test_fps_below_10_defaults_to_30
    # If FPS is unreasonably low, default to 30
    @estimator.record_beat(0, fps: 5.0)
    @estimator.record_beat(15, fps: 5.0)
    @estimator.record_beat(30, fps: 5.0)
    # With default 30fps: 60/(15/30) = 120 BPM
    assert_equal 120, @estimator.estimated_bpm
  end
end
