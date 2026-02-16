class ParticleSystem
  def initialize
    @particles = Array.new(VisualizerPolicy::PARTICLE_COUNT) do
      range = VisualizerPolicy::PARTICLE_SPAWN_RANGE
      {
        position: [rand_range(-range, range), rand_range(-range, range), rand_range(-range, range)],
        velocity: [0, 0, 0],
        color: [0.3, 0.3, 0.3]
      }
    end
    @color_cache_counter = 0
    @color_cache_interval = 3
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

    base_color = ColorPalette.frequency_to_color(analysis)

    brightness = 0.3 + Math.tanh(energy * 1.5) * 1.2
    brightness += 0.3 * imp_overall
    brightness = [brightness, 1.5].min

    explosion_probability = VisualizerPolicy.particle_explosion_base_prob + energy * VisualizerPolicy.particle_explosion_energy_scale
    explosion_force = energy * VisualizerPolicy.particle_explosion_force_scale

    explosion_probability = [explosion_probability + 0.3 * imp_overall, 0.9].min
    explosion_force += 0.35 * imp_overall

    @particles.each_with_index do |particle, idx|
      freq_type = idx % 3

      case freq_type
      when 0  # bass: radial explosion
        trigger = bass > 0.4 || imp_bass > 0.3
        if trigger && rand < explosion_probability
          direction = normalize_vector(particle[:position])
          force = explosion_force * (2.0 + imp_bass * 1.0)
          particle[:velocity] = direction.map { |d| d * force }
        end

      when 1  # mid: spiral motion
        trigger = mid > 0.3 || imp_mid > 0.3
        if trigger && rand < explosion_probability * 0.8
          angle = rand * Math::PI * 2
          force = explosion_force * (1.5 + imp_mid * 1.0)
          particle[:velocity] = [
            Math.cos(angle) * force,
            force,
            Math.sin(angle) * force
          ]
        end

      when 2  # high: upward burst
        trigger = high > 0.3 || imp_high > 0.3
        if trigger && rand < explosion_probability * 0.7
          force = explosion_force * (2.5 + imp_high * 1.0)
          particle[:velocity] = [
            rand_range(-explosion_force, explosion_force) * 0.5,
            force,
            rand_range(-explosion_force, explosion_force) * 0.5
          ]
        end
      end

      if @color_cache_counter == 0
        pos = particle[:position]
        dist = Math.sqrt(pos[0]**2 + pos[1]**2 + pos[2]**2)
        normalized_dist = [dist / 10.0, 1.0].min
        dist_color = ColorPalette.frequency_to_color_at_distance(analysis, normalized_dist)
        color_with_brightness = dist_color.map { |c| [c * brightness, 0.0].max }
        particle[:color] = VisualizerPolicy.cap_rgb(*color_with_brightness)
      end

      particle[:position][0] += particle[:velocity][0]
      particle[:position][1] += particle[:velocity][1]
      particle[:position][2] += particle[:velocity][2]

      particle[:velocity][0] *= VisualizerPolicy.particle_friction
      particle[:velocity][1] *= VisualizerPolicy.particle_friction
      particle[:velocity][2] *= VisualizerPolicy.particle_friction

      3.times do |i|
        if particle[:position][i].abs > VisualizerPolicy::PARTICLE_BOUNDARY
          range = VisualizerPolicy::PARTICLE_SPAWN_RANGE
          particle[:position][i] = rand_range(-range, range)
          particle[:velocity][i] = 0
        end
      end
    end

    @color_cache_counter = (@color_cache_counter + 1) % @color_cache_interval
  end

  def get_data
    positions = []
    colors = []
    total_size = 0.0
    total_opacity = 0.0

    @particles.each do |p|
      positions.concat(p[:position])
      colors.concat(p[:color])

      brightness = (p[:color][0] + p[:color][1] + p[:color][2]) / 3.0
      size = (0.05 + brightness * 0.25) * 2.5
      total_size += size

      opacity = (0.6 + brightness * 0.4)
      opacity = [opacity, 1.0].min
      total_opacity += opacity
    end

    avg_size = @particles.length > 0 ? total_size / @particles.length : 0.05
    avg_opacity = @particles.length > 0 ? total_opacity / @particles.length : 0.8

    {
      positions: positions,
      colors: colors,
      avg_size: avg_size,
      avg_opacity: avg_opacity
    }
  end

  private

  def normalize_vector(vec)
    magnitude = Math.sqrt(vec[0]**2 + vec[1]**2 + vec[2]**2)
    return [0, 0, 0] if magnitude < 0.001
    vec.map { |v| v / magnitude }
  end

  def rand_range(min, max)
    min + rand * (max - min)
  end
end
