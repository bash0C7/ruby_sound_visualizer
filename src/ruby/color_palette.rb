class ColorPalette
  attr_reader :hue_offset, :last_hsv
  attr_accessor :hue_mode

  BASE_HUES = { 1 => 0.0, 2 => 60.0, 3 => 180.0 }
  HUE_RANGE = 140.0

  def initialize
    @hue_mode = nil
    @hue_offset = 0.0
    @last_hsv = [0, 0, 0.3]
  end

  def hue_mode=(mode)
    @hue_mode = mode
    @hue_offset = 0.0
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

    value = VisualizerPolicy.cap_value(0.4 + Math.tanh(total * 0.5) * 0.3)

    if @hue_mode.nil?
      @last_hsv = [0, 0, value]
      return hsv_to_rgb(0, 0, value)
    end

    position = (mid * 0.5 + high * 1.0) / total
    base_hue = BASE_HUES[@hue_mode] || 0.0
    hue_offset_deg = (position - 0.5) * HUE_RANGE
    hue = ((base_hue + hue_offset_deg + @hue_offset) % 360.0) / 360.0

    saturation = VisualizerPolicy.cap_saturation(0.65 + Math.tanh(total * 0.5) * 0.15)

    @last_hsv = [hue, saturation, value]
    hsv_to_rgb(hue, saturation, value)
  end

  def frequency_to_color_at_distance(analysis, distance)
    bass = analysis[:bass]
    mid = analysis[:mid]
    high = analysis[:high]

    total = bass + mid + high
    return [0.3, 0.3, 0.3] if total < 0.01

    value = VisualizerPolicy.cap_value(0.4 + Math.tanh(total * 0.5) * 0.3)

    return hsv_to_rgb(0, 0, value) if @hue_mode.nil?

    base_hue = BASE_HUES[@hue_mode] || 0.0
    hue_offset_deg = (distance - 0.5) * HUE_RANGE
    hue = ((base_hue + hue_offset_deg + @hue_offset) % 360.0) / 360.0

    saturation = VisualizerPolicy.cap_saturation(0.65 + Math.tanh(total * 0.5) * 0.15)

    hsv_to_rgb(hue, saturation, value)
  end

  def energy_to_brightness(energy)
    0.5 + (energy ** 0.4) * 2.5
  end

  # Class-level API delegates to shared singleton instance
  @@shared_instance = nil

  def self.shared
    @@shared_instance ||= new
  end

  CLASS_DELEGATIONS = {
    set_hue_mode: :hue_mode=,
    get_hue_mode: :hue_mode,
    get_hue_offset: :hue_offset,
    set_hue_offset: :hue_offset=,
    get_last_hsv: :last_hsv,
    shift_hue_offset: :shift_hue_offset,
    frequency_to_color: :frequency_to_color,
    frequency_to_color_at_distance: :frequency_to_color_at_distance,
    energy_to_brightness: :energy_to_brightness,
  }.freeze

  CLASS_DELEGATIONS.each do |class_method, instance_method|
    define_singleton_method(class_method) { |*args| shared.send(instance_method, *args) }
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
