# Estimates BPM from beat detection intervals.
# Extracted from main.rb to isolate BPM calculation concerns.
class BPMEstimator
  attr_reader :estimated_bpm, :frame_count

  def initialize
    @beat_times = []
    @estimated_bpm = 0
    @frame_count = 0
  end

  def tick
    @frame_count += 1
  end

  def record_beat(frame_number, fps: 30.0)
    @beat_times << frame_number
    @beat_times = @beat_times.last(16) if @beat_times.length > 16
    recalculate(fps)
  end

  private

  def recalculate(fps)
    return if @beat_times.length < 3

    # Clamp extremely low FPS to 10 instead of 30 for gentler degradation
    fps = 10.0 if fps < 10

    intervals = []
    (@beat_times.length - 1).times do |i|
      intervals << @beat_times[i + 1] - @beat_times[i]
    end
    avg_interval = intervals.sum.to_f / intervals.length
    return if avg_interval <= 0

    bpm = (60.0 / (avg_interval / fps)).round(0)
    @estimated_bpm = (bpm >= 40 && bpm <= 240) ? bpm : 0
  end
end
