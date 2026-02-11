# Tracks frame rate and provides FPS reporting.
# Replaces JavaScript-side FPS counting with Ruby-side calculation.
class FrameCounter
  attr_reader :current_fps

  def initialize
    @frame_count = 0
    @last_report_time = nil
    @current_fps = 0
    @report_ready = false
  end

  def tick(timestamp_ms)
    @frame_count += 1
    @last_report_time ||= timestamp_ms

    elapsed = timestamp_ms - @last_report_time
    if elapsed >= 1000
      @current_fps = (@frame_count * 1000.0 / elapsed).round(0).to_i
      @frame_count = 0
      @last_report_time = timestamp_ms
      @report_ready = true
    end
  end

  def report_ready?
    @report_ready
  end

  def clear_report
    @report_ready = false
  end

  def fps_text
    "FPS: #{@current_fps}"
  end
end
