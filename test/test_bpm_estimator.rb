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

  def test_fps_below_10_clamps_to_10
    # If FPS is unreasonably low (< 10), clamp to 10 instead of jumping to 30
    # This provides gentler degradation and closer approximation to actual FPS
    @estimator.record_beat(0, fps: 5.0)
    @estimator.record_beat(5, fps: 5.0)
    @estimator.record_beat(10, fps: 5.0)
    # With clamped 10fps: 60/(5/10) = 120 BPM
    assert_equal 120, @estimator.estimated_bpm
  end

  def test_bpm_at_15_fps
    # Simulate 120 BPM at 15fps: beat every 7.5 frames
    # 120 BPM = 2 beats/sec, interval = 0.5 sec = 7.5 frames at 15fps
    @estimator.record_beat(0, fps: 15.0)
    @estimator.record_beat(8, fps: 15.0)   # ~0.53 sec
    @estimator.record_beat(15, fps: 15.0)  # ~1.0 sec
    # Average interval: (8+7)/2 = 7.5 frames, 7.5/15 = 0.5 sec, 60/0.5 = 120 BPM
    assert_equal 120, @estimator.estimated_bpm
  end

  def test_bpm_at_20_fps
    # Simulate 120 BPM at 20fps: beat every 10 frames
    # 120 BPM = 2 beats/sec, interval = 0.5 sec = 10 frames at 20fps
    @estimator.record_beat(0, fps: 20.0)
    @estimator.record_beat(10, fps: 20.0)
    @estimator.record_beat(20, fps: 20.0)
    assert_equal 120, @estimator.estimated_bpm
  end

  def test_bpm_at_25_fps
    # Simulate 120 BPM at 25fps: beat every 12.5 frames
    # 120 BPM = 2 beats/sec, interval = 0.5 sec = 12.5 frames at 25fps
    @estimator.record_beat(0, fps: 25.0)
    @estimator.record_beat(12, fps: 25.0)  # ~0.48 sec
    @estimator.record_beat(25, fps: 25.0)  # ~1.0 sec
    # Average interval: (12+13)/2 = 12.5 frames, 12.5/25 = 0.5 sec, 60/0.5 = 120 BPM
    assert_equal 120, @estimator.estimated_bpm
  end

  def test_bpm_at_10_fps_boundary
    # Boundary: exactly 10 FPS should use actual value, not default to 30
    # Simulate 120 BPM at 10fps: beat every 5 frames
    # 120 BPM = 2 beats/sec, interval = 0.5 sec = 5 frames at 10fps
    @estimator.record_beat(0, fps: 10.0)
    @estimator.record_beat(5, fps: 10.0)
    @estimator.record_beat(10, fps: 10.0)
    assert_equal 120, @estimator.estimated_bpm
  end

  # === C-10: Variable FPS scenario tests ===

  def test_bpm_with_varying_fps_between_beats
    # Real browser FPS fluctuates between beats
    @estimator.record_beat(0, fps: 55.0)
    @estimator.record_beat(28, fps: 62.0)
    @estimator.record_beat(58, fps: 58.0)
    bpm = @estimator.estimated_bpm
    # Should produce a reasonable BPM (around 120 with ~30 frame intervals at ~60fps)
    assert bpm >= 100 && bpm <= 140, "BPM #{bpm} should be roughly 120 with variable FPS"
  end

  def test_bpm_stable_despite_fps_jitter
    # Simulate consistent beats with jittering FPS
    fps_values = [58, 62, 55, 65, 60]
    5.times do |i|
      @estimator.record_beat(i * 30, fps: fps_values[i].to_f)
    end
    bpm = @estimator.estimated_bpm
    assert bpm > 0, "BPM should be calculable despite FPS jitter"
    assert bpm >= 80 && bpm <= 160, "BPM #{bpm} should be reasonable despite FPS jitter"
  end

  def test_bpm_with_fps_zero_uses_clamp
    @estimator.record_beat(0, fps: 0.0)
    @estimator.record_beat(5, fps: 0.0)
    @estimator.record_beat(10, fps: 0.0)
    # Should not crash; FPS 0 gets clamped to 10
    bpm = @estimator.estimated_bpm
    assert_kind_of Integer, bpm
  end
end
