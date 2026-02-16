class GeometryMorpher
  def initialize
    @rotation = [0, 0, 0]
    @scale = VisualizerPolicy::GEOMETRY_BASE_SCALE
    @emissive_intensity = 0.0
    @color = [0.3, 0.3, 0.3]
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
    @scale += 0.8 * imp_overall

    @rotation[0] += bass * 0.15
    @rotation[1] += mid * 0.1
    @rotation[2] += high * 0.08

    @rotation[0] += 0.5 * imp_bass
    @rotation[1] += 0.4 * imp_mid
    @rotation[2] += 0.3 * imp_high

    @emissive_intensity = Math.tanh(energy * 1.5) * 1.5
    @emissive_intensity += Math.tanh(imp_overall) * 0.8
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
