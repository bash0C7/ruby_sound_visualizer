# Generates RGB colors based on audio frequency and energy.
# Instance-based: each instance holds its own hue_mode, hue_offset state.
class ColorPalette
  attr_reader :hue_offset, :last_hsv
  attr_accessor :hue_mode

  def initialize
    @hue_mode = nil    # nil = grayscale, 1,2,3 = hue modes
    @hue_offset = 0.0  # manual offset (degrees, 0-360 circular)
    @last_hsv = [0, 0, 0.3]
  end

  def hue_mode=(mode)
    @hue_mode = mode
    @hue_offset = 0.0  # reset offset on preset change
  end

  def shift_hue_offset(delta)
    @hue_offset = (@hue_offset + delta) % 360.0
  end

  def frequency_to_color(analysis)
    bass = analysis[:bass]
    mid = analysis[:mid]
    high = analysis[:high]

    total = bass + mid + high

    if total < 0.01
      @last_hsv = [0, 0, 0.3]
      return [0.3, 0.3, 0.3]
    end

    # Soft-clipped value to prevent saturation at high volume
    value = 0.4 + Math.tanh(total * 0.5) * 0.3

    # Max lightness cap
    max_v = Config.max_lightness / 255.0
    value = [value, max_v].min if Config.max_lightness < 255

    # Grayscale mode
    if @hue_mode.nil?
      @last_hsv = [0, 0, value]
      return hsv_to_rgb(0, 0, value)
    end

    # Hue shift: bass=0.0, mid=0.5, high=1.0 weighted
    hue_shift = total > 0.01 ? (mid * 0.5 + high * 1.0) / total : 0.5

    # Mode-specific hue range (240 degrees each) + manual offset
    offset = @hue_offset / 360.0
    hue = case @hue_mode
    when 1 then (0.667 + offset + hue_shift * 0.667) % 1.0  # Red center
    when 2 then (offset + hue_shift * 0.667) % 1.0           # Green center
    when 3 then (0.333 + offset + hue_shift * 0.667) % 1.0   # Blue center
    else 0
    end

    # Saturation: soft-clipped
    saturation = 0.65 + Math.tanh(total * 0.5) * 0.15

    @last_hsv = [hue, saturation, value]
    hsv_to_rgb(hue, saturation, value)
  end

  # Distance-based color (circular gradient)
  def frequency_to_color_at_distance(analysis, distance)
    bass = analysis[:bass]
    mid = analysis[:mid]
    high = analysis[:high]

    total = bass + mid + high
    return [0.3, 0.3, 0.3] if total < 0.01

    value = 0.4 + Math.tanh(total * 0.5) * 0.3

    max_v = Config.max_lightness / 255.0
    value = [value, max_v].min if Config.max_lightness < 255

    return hsv_to_rgb(0, 0, value) if @hue_mode.nil?

    offset = @hue_offset / 360.0
    hue = case @hue_mode
    when 1 then (0.667 + offset + distance * 0.667) % 1.0
    when 2 then (offset + distance * 0.667) % 1.0
    when 3 then (0.333 + offset + distance * 0.667) % 1.0
    else 0
    end

    saturation = 0.65 + Math.tanh(total * 0.5) * 0.15

    hsv_to_rgb(hue, saturation, value)
  end

  def energy_to_brightness(energy)
    0.5 + (energy ** 0.4) * 2.5
  end

  # Class-level shared instance for backward compatibility
  # Used by KeyboardHandler, DebugFormatter, and main.rb during transition
  @@shared_instance = nil

  def self.shared
    @@shared_instance ||= new
  end

  def self.set_hue_mode(mode)
    shared.hue_mode = mode
  end

  def self.get_hue_mode
    shared.hue_mode
  end

  def self.get_hue_offset
    shared.hue_offset
  end

  def self.shift_hue_offset(delta)
    shared.shift_hue_offset(delta)
  end

  def self.get_last_hsv
    shared.last_hsv
  end

  def self.frequency_to_color(analysis)
    shared.frequency_to_color(analysis)
  end

  def self.frequency_to_color_at_distance(analysis, distance)
    shared.frequency_to_color_at_distance(analysis, distance)
  end

  def self.energy_to_brightness(energy)
    shared.energy_to_brightness(energy)
  end

  private

  def hsv_to_rgb(h, s, v)
    c = v * s
    x = c * (1 - ((h * 6) % 2 - 1).abs)
    m = v - c

    r, g, b = case (h * 6).floor
    when 0 then [c, x, 0]
    when 1 then [x, c, 0]
    when 2 then [0, c, x]
    when 3 then [0, x, c]
    when 4 then [x, 0, c]
    else [c, 0, x]
    end

    [r + m, g + m, b + m]
  end
end
