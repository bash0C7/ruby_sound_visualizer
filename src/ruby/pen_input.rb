# PenInput: Mouse-driven pen drawing with fade-out.
# Manages stroke collection, color sync with particle system, and fade-out timing.
# Rendering is delegated to JavaScript via penDrawStrokes().
# Color matches current visualizer particle color palette for
# a "Gakuen Idolmaster" girly handwritten font aesthetic.
class PenInput
  # Fade-out timing
  FADE_DURATION_FRAMES = 180  # 3 seconds at 60fps
  STROKE_WIDTH = 3.0
  MAX_STROKES = 50

  Stroke = Struct.new(:points, :color, :width, :opacity, :created_frame, keyword_init: true)

  attr_reader :strokes

  def initialize
    @strokes = []
    @current_stroke = nil
    @drawing = false
    @frame = 0
    @hue = 0.0
  end

  # Start a new stroke at given position
  def start_stroke(x, y)
    @drawing = true
    @hue = current_hue
    color = hue_to_css_color(@hue)
    @current_stroke = Stroke.new(
      points: [[x, y]],
      color: color,
      width: STROKE_WIDTH,
      opacity: 1.0,
      created_frame: @frame
    )
    @strokes << @current_stroke
    # Limit total strokes
    @strokes.shift while @strokes.length > MAX_STROKES
  end

  # Add a point to the current stroke
  def add_point(x, y)
    return unless @drawing && @current_stroke

    last = @current_stroke.points.last
    return if last && (last[0] - x).abs < 1 && (last[1] - y).abs < 1

    @current_stroke.points << [x, y]
  end

  # End the current stroke
  def end_stroke
    @drawing = false
    @current_stroke = nil
  end

  # Update per frame: advance frame counter and apply fade-out
  def update
    @frame += 1
    @strokes.each do |stroke|
      age = @frame - stroke.created_frame
      if age >= FADE_DURATION_FRAMES
        stroke.opacity = 0.0
      else
        stroke.opacity = 1.0 - (age.to_f / FADE_DURATION_FRAMES)
      end
    end
    # Remove fully faded strokes
    @strokes.reject! { |s| s.opacity <= 0.0 }
  end

  # Check if there are visible strokes to render
  def has_visible_strokes?
    !@strokes.empty?
  end

  # Clear all strokes
  def clear
    @strokes = []
    @current_stroke = nil
    @drawing = false
  end

  # Generate JSON for JS canvas rendering
  def to_render_json
    return '[]' if @strokes.empty?
    parts = @strokes.map do |s|
      points_json = s.points.map { |p| "[#{p[0]},#{p[1]}]" }.join(',')
      "{\"points\":[#{points_json}],\"color\":\"#{s.color}\",\"width\":#{s.width},\"opacity\":#{s.opacity.round(3)}}"
    end
    "[#{parts.join(',')}]"
  end

  private

  # Get current hue from ColorPalette (synced with particle colors)
  def current_hue
    mode = ColorPalette.get_hue_mode
    offset = ColorPalette.get_hue_offset
    base_hue = case mode
               when nil, 0 then 300  # Pink/magenta for girly aesthetic in grayscale mode
               when 1 then 330       # Pink-red
               when 2 then 50        # Warm gold
               when 3 then 200       # Light blue
               else 300
               end
    (base_hue + offset) % 360
  end

  # Convert HSL hue to CSS color string (high saturation, medium lightness)
  def hue_to_css_color(hue)
    "hsl(#{hue.round(1)}, 100%, 70%)"
  end
end
