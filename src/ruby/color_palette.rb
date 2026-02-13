# Generates RGB colors based on audio frequency and energy.
# Instance-based: each instance holds its own hue_mode, hue_offset state.
class ColorPalette
  attr_reader :hue_offset, :last_hsv
  attr_accessor :hue_mode

  # Base hue for each mode (in degrees, 0-360)
  BASE_HUES = { 1 => 0.0, 2 => 60.0, 3 => 180.0 }
  # Hue range: ±70 degrees from base (total 140 degrees)
  HUE_RANGE = 140.0

  def initialize
    @hue_mode = nil    # nil = grayscale, 1,2,3 = hue modes
    @hue_offset = 0.0  # manual offset (degrees, 0-360 circular)
    @last_hsv = [0, 0, 0.3]
  end

  def hue_mode=(mode)
    @hue_mode = mode
    @hue_offset = 0.0  # reset offset on preset change
  end

  def hue_offset=(val)
    @hue_offset = val.to_f % 360.0
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

    # Max lightness cap (via VisualizerPolicy)
    value = VisualizerPolicy.cap_value(value)

    # Grayscale mode
    if @hue_mode.nil?
      @last_hsv = [0, 0, value]
      return hsv_to_rgb(0, 0, value)
    end

    # Three-band hue mapping: bass=0.0 (base-70deg), mid=0.5 (base), high=1.0 (base+70deg)
    position = total > 0.01 ? (mid * 0.5 + high * 1.0) / total : 0.5

    # Calculate hue: base + offset from position (-70 to +70 degrees)
    base_hue = BASE_HUES[@hue_mode] || 0.0
    hue_offset_deg = (position - 0.5) * HUE_RANGE
    hue_deg = (base_hue + hue_offset_deg + @hue_offset) % 360.0
    hue = hue_deg / 360.0

    # Saturation: soft-clipped, then capped by VisualizerPolicy
    saturation = VisualizerPolicy.cap_saturation(0.65 + Math.tanh(total * 0.5) * 0.15)

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

    # Max lightness cap (via VisualizerPolicy)
    value = VisualizerPolicy.cap_value(value)

    return hsv_to_rgb(0, 0, value) if @hue_mode.nil?

    # Distance-based hue: use same 140-degree range as frequency-based
    base_hue = BASE_HUES[@hue_mode] || 0.0
    hue_offset_deg = (distance - 0.5) * HUE_RANGE
    hue_deg = (base_hue + hue_offset_deg + @hue_offset) % 360.0
    hue = hue_deg / 360.0

    saturation = VisualizerPolicy.cap_saturation(0.65 + Math.tanh(total * 0.5) * 0.15)

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

  def self.set_hue_offset(val)
    shared.hue_offset = val
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
