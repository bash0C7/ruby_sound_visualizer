class WordartRenderer
  # Animation phases
  PHASE_NONE = :none
  PHASE_ENTRANCE = :entrance
  PHASE_SUSTAIN = :sustain
  PHASE_EXIT = :exit

  # Timing (in frames at ~60fps)
  ENTRANCE_FRAMES = 30   # 0.5s entrance
  SUSTAIN_FRAMES = 180   # 3s display
  EXIT_FRAMES = 45       # 0.75s exit

  # WordArt style presets (rotated through)
  STYLES = [
    {
      name: 'rainbow_arc',
      gradient_type: 'linear',
      stops: [[0.0, '#ff0000'], [0.25, '#ffff00'], [0.5, '#00ff00'], [0.75, '#0088ff'], [1.0, '#ff00ff']],
      outline_color: '#000',
      outline_width: 4,
      bold: true,
      italic: false,
      font_family: 'Impact, Arial Black, sans-serif',
      entrance: :zoom_spin,
      exit: :fade_shrink
    },
    {
      name: 'gold_emboss',
      gradient_type: 'linear',
      stops: [[0.0, '#ffd700'], [0.3, '#fff8dc'], [0.5, '#ffd700'], [0.7, '#daa520'], [1.0, '#b8860b']],
      outline_color: '#8b4513',
      outline_width: 3,
      bold: true,
      italic: true,
      font_family: 'Georgia, Times New Roman, serif',
      shadow: { color: 'rgba(0,0,0,0.6)', blur: 8, x: 4, y: 4 },
      entrance: :slide_bounce,
      exit: :slide_out
    },
    {
      name: 'neon_glow',
      gradient_type: 'radial',
      stops: [[0.0, '#ff00ff'], [0.5, '#00ffff'], [1.0, '#ff00ff']],
      outline_color: '#fff',
      outline_width: 2,
      bold: true,
      italic: false,
      font_family: 'Impact, Arial Black, sans-serif',
      shadow: { color: '#ff00ff', blur: 20, x: 0, y: 0 },
      entrance: :typewriter,
      exit: :glitch_out
    },
    {
      name: 'chrome_3d',
      gradient_type: 'linear',
      stops: [[0.0, '#c0c0c0'], [0.3, '#ffffff'], [0.5, '#808080'], [0.7, '#ffffff'], [1.0, '#c0c0c0']],
      outline_color: '#333',
      outline_width: 3,
      bold: true,
      italic: false,
      font_family: 'Arial Black, Impact, sans-serif',
      shadow: { color: 'rgba(0,0,0,0.8)', blur: 3, x: 3, y: 5 },
      entrance: :drop_in,
      exit: :fade_shrink
    }
  ].freeze

  attr_reader :phase, :text, :style_index

  def initialize
    @phase = PHASE_NONE
    @text = ''
    @frame = 0
    @style_index = 0
    @entrance_type = :zoom_spin
    @exit_type = :fade_shrink
    @audio_energy = 0.0
  end

  def active?
    @phase != PHASE_NONE
  end

  # Trigger a new WordArt display
  def trigger(text, style_index: nil)
    return if text.nil? || text.strip.empty?
    @text = text.strip
    @style_index = style_index || (@style_index % STYLES.length)
    style = STYLES[@style_index]
    @entrance_type = style[:entrance] || :zoom_spin
    @exit_type = style[:exit] || :fade_shrink
    @phase = PHASE_ENTRANCE
    @frame = 0
    @style_index = (@style_index + 1) % STYLES.length
    @text
  end

  # Update animation state per frame
  def update(analysis = nil)
    return unless active?

    @audio_energy = analysis[:overall_energy].to_f if analysis.is_a?(Hash)
    @frame += 1

    case @phase
    when PHASE_ENTRANCE
      if @frame >= ENTRANCE_FRAMES
        @phase = PHASE_SUSTAIN
        @frame = 0
      end
    when PHASE_SUSTAIN
      if @frame >= SUSTAIN_FRAMES
        @phase = PHASE_EXIT
        @frame = 0
      end
    when PHASE_EXIT
      if @frame >= EXIT_FRAMES
        @phase = PHASE_NONE
        @frame = 0
      end
    end
  end

  # Force stop current animation
  def stop
    @phase = PHASE_NONE
    @frame = 0
  end

  # Generate render data hash for JS canvas
  def render_data
    return nil unless active?

    style = current_style
    progress = phase_progress

    base = {
      text: @text,
      fontSize: 72,
      fontFamily: style[:font_family],
      bold: style[:bold],
      italic: style[:italic],
      outlineColor: style[:outline_color],
      outlineWidth: style[:outline_width],
      gradient: {
        type: style[:gradient_type],
        stops: style[:stops],
        radius: 200
      }
    }

    base[:shadow] = style[:shadow] if style[:shadow]

    # Apply animation transforms
    apply_animation(base, progress)
    base
  end

  # Serialize render data to JSON string for JS
  def to_render_json
    data = render_data
    return '{}' unless data
    hash_to_json(data)
  end

  private

  def current_style
    idx = (@style_index - 1) % STYLES.length
    STYLES[idx]
  end

  def phase_progress
    case @phase
    when PHASE_ENTRANCE
      @frame.to_f / ENTRANCE_FRAMES
    when PHASE_SUSTAIN
      1.0
    when PHASE_EXIT
      @frame.to_f / EXIT_FRAMES
    else
      0.0
    end
  end

  def apply_animation(data, progress)
    case @phase
    when PHASE_ENTRANCE
      apply_entrance(data, progress)
    when PHASE_SUSTAIN
      apply_sustain(data)
    when PHASE_EXIT
      apply_exit(data, progress)
    end
  end

  def apply_entrance(data, t)
    case @entrance_type
    when :zoom_spin
      # Scale from 0 to 1 with overshoot, spin 360 degrees
      ease = ease_out_back(t)
      data[:scale] = ease
      data[:rotation] = (1.0 - t) * Math::PI * 2
      data[:opacity] = [t * 2, 1.0].min
    when :slide_bounce
      # Slide in from top with bounce
      ease = ease_out_bounce(t)
      data[:scale] = 1.0
      data[:y_offset] = (1.0 - ease) * -300
      data[:opacity] = [t * 3, 1.0].min
    when :typewriter
      # Reveal characters one by one
      visible_chars = (t * @text.length).ceil
      data[:text] = @text[0, visible_chars]
      data[:scale] = 1.0
      data[:opacity] = 1.0
    when :drop_in
      # Drop from top with gravity
      ease = ease_out_cubic(t)
      data[:scale] = 1.0 + (1.0 - ease) * 0.5
      data[:y_offset] = (1.0 - ease) * -400
      data[:opacity] = [t * 2, 1.0].min
    end
  end

  def apply_sustain(data)
    # Subtle audio-reactive pulsing during sustain
    pulse = 1.0 + @audio_energy * 0.15
    data[:scale] = pulse
    data[:opacity] = 1.0
    # Gentle floating motion
    float_y = Math.sin(@frame * 0.05) * 5
    data[:y_offset] = float_y
  end

  def apply_exit(data, t)
    case @exit_type
    when :fade_shrink
      ease = ease_in_cubic(t)
      data[:scale] = 1.0 - ease * 0.5
      data[:opacity] = 1.0 - ease
    when :slide_out
      ease = ease_in_cubic(t)
      data[:scale] = 1.0
      data[:y_offset] = ease * 400
      data[:opacity] = 1.0 - ease
    when :glitch_out
      # Glitch effect: random offset and opacity flicker
      if t < 0.7
        data[:scale] = 1.0
        data[:opacity] = t < 0.5 ? (rand > 0.3 ? 1.0 : 0.0) : (rand > 0.5 ? 0.7 : 0.0)
        data[:x_offset] = (rand - 0.5) * 20 * t
      else
        data[:opacity] = 0.0
      end
    end
  end

  # Easing functions
  def ease_out_back(t)
    c1 = 1.70158
    c3 = c1 + 1
    1 + c3 * ((t - 1) ** 3) + c1 * ((t - 1) ** 2)
  end

  def ease_out_bounce(t)
    if t < 1.0 / 2.75
      7.5625 * t * t
    elsif t < 2.0 / 2.75
      t2 = t - 1.5 / 2.75
      7.5625 * t2 * t2 + 0.75
    elsif t < 2.5 / 2.75
      t2 = t - 2.25 / 2.75
      7.5625 * t2 * t2 + 0.9375
    else
      t2 = t - 2.625 / 2.75
      7.5625 * t2 * t2 + 0.984375
    end
  end

  def ease_out_cubic(t)
    1 - ((1 - t) ** 3)
  end

  def ease_in_cubic(t)
    t ** 3
  end

  def hash_to_json(obj)
    case obj
    when Hash
      pairs = obj.map { |k, v| "\"#{escape_json(k.to_s)}\":#{hash_to_json(v)}" }
      "{#{pairs.join(',')}}"
    when Array
      "[#{obj.map { |v| hash_to_json(v) }.join(',')}]"
    when String
      "\"#{escape_json(obj)}\""
    when true then 'true'
    when false then 'false'
    when nil then 'null'
    when Numeric then obj.to_s
    when Symbol then "\"#{escape_json(obj.to_s)}\""
    else
      "\"#{escape_json(obj.to_s)}\""
    end
  end

  def escape_json(s)
    s.gsub(/[\\"\n\r\t]/) do |c|
      case c
      when '\\' then '\\\\'
      when '"'  then '\\"'
      when "\n" then '\\n'
      when "\r" then '\\r'
      when "\t" then '\\t'
      end
    end
  end
end
