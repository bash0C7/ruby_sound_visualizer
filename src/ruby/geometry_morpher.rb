class GeometryMorpher
  DEFAULT_COLOR = [0.3, 0.3, 0.3].freeze
  IMPULSE_SCALE = 0.8
  ROTATION_BASS = 0.15
  ROTATION_MID = 0.1
  ROTATION_HIGH = 0.08
  IMPULSE_ROTATION_BASS = 0.5
  IMPULSE_ROTATION_MID = 0.4
  IMPULSE_ROTATION_HIGH = 0.3
  EMISSIVE_SCALE = 1.5
  EMISSIVE_IMPULSE = 0.8

  def initialize
    @rotation = [0, 0, 0]
    @scale = VisualizerPolicy::GEOMETRY_BASE_SCALE
    @emissive_intensity = 0.0
    @color = DEFAULT_COLOR.dup
  end

  def update(analysis)
    energy = analysis[:overall_energy]
    bass = analysis[:bass]
    mid = analysis[:mid]
    high = analysis[:high]
    impulse = analysis[:impulse] || {}
    imp_overall = impulse[:overall] || 0.0
    imp_bass = impulse[:bass] || 0.0
    imp_mid = impulse[:mid] || 0.0
    imp_high = impulse[:high] || 0.0

    @color = ColorPalette.frequency_to_color(analysis)

    @scale = VisualizerPolicy::GEOMETRY_BASE_SCALE + energy * VisualizerPolicy::GEOMETRY_SCALE_MULTIPLIER
    @scale += IMPULSE_SCALE * imp_overall

    @rotation[0] += bass * ROTATION_BASS
    @rotation[1] += mid * ROTATION_MID
    @rotation[2] += high * ROTATION_HIGH

    @rotation[0] += IMPULSE_ROTATION_BASS * imp_bass
    @rotation[1] += IMPULSE_ROTATION_MID * imp_mid
    @rotation[2] += IMPULSE_ROTATION_HIGH * imp_high

    @emissive_intensity = Math.tanh(energy * EMISSIVE_SCALE) * EMISSIVE_SCALE
    @emissive_intensity += Math.tanh(imp_overall) * EMISSIVE_IMPULSE
    @emissive_intensity = VisualizerPolicy.cap_emissive(@emissive_intensity)
  end

  def get_data
    {
      scale: @scale,
      rotation: @rotation,
      emissive_intensity: @emissive_intensity,
      color: @color
    }
  end
end
