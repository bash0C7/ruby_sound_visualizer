require_relative 'test_helper'

class TestFrameCounter < Test::Unit::TestCase
  def test_initial_state
    counter = FrameCounter.new
    assert_equal 0, counter.current_fps
    assert_equal false, counter.report_ready?
  end

  def test_tick_accumulates_frames
    counter = FrameCounter.new
    counter.tick(1000.0)
    counter.tick(1016.0)
    counter.tick(1032.0)
    assert_equal false, counter.report_ready?
  end

  def test_tick_reports_after_one_second
    counter = FrameCounter.new
    # Simulate 30 frames over 1 second
    30.times do |i|
      counter.tick(1000.0 + i * 33.3)
    end
    counter.tick(2001.0)  # Just past 1 second
    assert_equal true, counter.report_ready?
    assert counter.current_fps > 0
  end

  def test_fps_calculation_accuracy
    counter = FrameCounter.new
    # 60 frames in exactly 1 second
    61.times do |i|
      counter.tick(1000.0 + i * 16.67)
    end
    # FPS should be approximately 60
    if counter.report_ready?
      assert_in_delta 60, counter.current_fps, 5
    end
  end

  def test_report_ready_resets_after_read
    counter = FrameCounter.new
    30.times { |i| counter.tick(1000.0 + i * 33.3) }
    counter.tick(2001.0)
    assert_equal true, counter.report_ready?
    counter.clear_report
    assert_equal false, counter.report_ready?
  end

  def test_fps_text
    counter = FrameCounter.new
    30.times { |i| counter.tick(1000.0 + i * 33.3) }
    counter.tick(2001.0)
    text = counter.fps_text
    assert_match(/FPS: \d+/, text)
  end
end
