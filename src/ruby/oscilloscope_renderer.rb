# OscilloscopeRenderer: 3D oscilloscope waveform visualization state.
# Manages a time-domain waveform buffer and a scrolling history ring buffer
# for rendering a ribbon of waveforms flowing left-to-right in Three.js.
# Positioned in front of VRM models and particles (closer to camera).
class OscilloscopeRenderer
  DEFAULT_BUFFER_SIZE = 256
  DEFAULT_HISTORY_DEPTH = 64
  DEFAULT_SCROLL_SPEED = 2.0
  SCROLL_SPEED_MIN = 0.1
  SCROLL_SPEED_MAX = 10.0
  DEFAULT_RIBBON_WIDTH = 20.0
  DEFAULT_RIBBON_HEIGHT = 3.0
  DEFAULT_Z_POSITION = 8.0
  DEFAULT_Y_POSITION = -2.0
  # Default green oscilloscope color
  DEFAULT_COLOR = [0.0, 1.0, 0.4].freeze

  attr_reader :buffer_size, :waveform_buffer, :scroll_offset, :intensity
  attr_reader :color, :scroll_speed, :ribbon_width, :ribbon_height
  attr_reader :z_position, :y_position, :history_depth

  def initialize(buffer_size: DEFAULT_BUFFER_SIZE, history_depth: DEFAULT_HISTORY_DEPTH)
    @buffer_size = buffer_size
    @history_depth = history_depth
    @waveform_buffer = Array.new(buffer_size, 0.0)
    @scroll_offset = 0.0
    @scroll_speed = DEFAULT_SCROLL_SPEED
    @intensity = 0.0
    @color = DEFAULT_COLOR.dup
    @ribbon_width = DEFAULT_RIBBON_WIDTH
    @ribbon_height = DEFAULT_RIBBON_HEIGHT
    @z_position = DEFAULT_Z_POSITION
    @y_position = DEFAULT_Y_POSITION
    @enabled = true
    @history = []
  end

  def enabled?
    @enabled
  end

  def enable
    @enabled = true
  end

  def disable
    @enabled = false
  end

  # Update the current waveform buffer from time-domain samples.
  # Samples are clamped to [-1.0, 1.0] and padded/truncated to buffer_size.
  def update_waveform(samples)
    @waveform_buffer = Array.new(@buffer_size, 0.0)
    count = [samples.length, @buffer_size].min
    count.times do |i|
      @waveform_buffer[i] = clamp_sample(samples[i].to_f)
    end
  end

  # Push current waveform to history ring buffer for 3D ribbon rendering.
  def push_to_history
    @history.push(@waveform_buffer.dup)
    @history.shift if @history.length > @history_depth
  end

  def history_length
    @history.length
  end

  # Advance scroll offset for left-to-right flow animation.
  # delta_ms: frame delta time in milliseconds.
  def advance_scroll(delta_ms)
    @scroll_offset += @scroll_speed * delta_ms / 1000.0
    @scroll_offset %= @ribbon_width if @scroll_offset >= @ribbon_width
  end

  def set_scroll_speed(val)
    @scroll_speed = clamp(val.to_f, SCROLL_SPEED_MIN, SCROLL_SPEED_MAX)
  end

  def set_intensity(val)
    @intensity = clamp(val.to_f, 0.0, 1.0)
  end

  def set_color(r, g, b)
    @color = [clamp(r.to_f, 0.0, 1.0), clamp(g.to_f, 0.0, 1.0), clamp(b.to_f, 0.0, 1.0)]
  end

  # Return all data needed by JS bridge for Three.js rendering.
  def render_data
    {
      waveform: @waveform_buffer,
      history: @history,
      scroll_offset: @scroll_offset,
      intensity: @intensity,
      color: @color,
      ribbon_width: @ribbon_width,
      ribbon_height: @ribbon_height,
      z_position: @z_position,
      y_position: @y_position,
      enabled: @enabled
    }
  end

  def status
    state = @enabled ? "on" : "off"
    "oscilloscope: #{state} speed=#{@scroll_speed} intensity=#{@intensity.round(2)} " \
      "history=#{@history.length}/#{@history_depth}"
  end

  private

  def clamp(val, min, max)
    [[val, min].max, max].min
  end

  def clamp_sample(val)
    [[val, -1.0].max, 1.0].min
  end
end
