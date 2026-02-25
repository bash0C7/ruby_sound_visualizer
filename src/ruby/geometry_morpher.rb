class GeometryMorpher
  DEFAULT_COLOR = [0.3, 0.3, 0.3].freeze

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
    @scale += VisualizerPolicy::GEOMETRY_IMPULSE_SCALE * imp_overall

    @rotation[0] += bass * VisualizerPolicy::GEOMETRY_ROTATION_BASS
    @rotation[1] += mid * VisualizerPolicy::GEOMETRY_ROTATION_MID
    @rotation[2] += high * VisualizerPolicy::GEOMETRY_ROTATION_HIGH

    @rotation[0] += VisualizerPolicy::GEOMETRY_IMPULSE_ROTATION_BASS * imp_bass
    @rotation[1] += VisualizerPolicy::GEOMETRY_IMPULSE_ROTATION_MID * imp_mid
    @rotation[2] += VisualizerPolicy::GEOMETRY_IMPULSE_ROTATION_HIGH * imp_high

    @emissive_intensity = Math.tanh(energy * VisualizerPolicy::GEOMETRY_EMISSIVE_SCALE) * VisualizerPolicy::GEOMETRY_EMISSIVE_SCALE
    @emissive_intensity += Math.tanh(imp_overall) * VisualizerPolicy::GEOMETRY_EMISSIVE_IMPULSE
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
