class EffectManager
  attr_reader :particle_data, :geometry_data, :bloom_data, :camera_data,
              :impulse_overall, :impulse_bass, :impulse_mid, :impulse_high,
              :bloom_flash

  def initialize
    @particle_system = ParticleSystem.new
    @geometry_morpher = GeometryMorpher.new
    @bloom_controller = BloomController.new
    @camera_controller = CameraController.new
    @impulse_overall = 0.0
    @impulse_bass = 0.0
    @impulse_mid = 0.0
    @impulse_high = 0.0
    @bloom_flash = 0.0
  end

  def inject_impulse(bass: 0.0, mid: 0.0, high: 0.0, overall: 0.0)
    @impulse_bass = [@impulse_bass, bass].max
    @impulse_mid = [@impulse_mid, mid].max
    @impulse_high = [@impulse_high, high].max
    @impulse_overall = [@impulse_overall, overall].max
  end

  def inject_bloom_flash(intensity)
    @bloom_flash = intensity.to_f
  end

  def update(analysis, sensitivity = 1.0)
    beat = analysis[:beat] || {}

    # ビート検出時に impulse を 1.0 にセット
    @impulse_bass = 1.0 if beat[:bass]
    @impulse_mid = 1.0 if beat[:mid]
    @impulse_high = 1.0 if beat[:high]
    @impulse_overall = 1.0 if beat[:overall]

    # 感度スケーリング + impulse を渡す
    scaled_analysis = {
      bass: [analysis[:bass] * sensitivity, 1.0].min,
      mid: [analysis[:mid] * sensitivity, 1.0].min,
      high: [analysis[:high] * sensitivity, 1.0].min,
      overall_energy: [analysis[:overall_energy] * sensitivity, 1.0].min,
      dominant_frequency: analysis[:dominant_frequency],
      impulse: {
        overall: @impulse_overall,
        bass: @impulse_bass,
        mid: @impulse_mid,
        high: @impulse_high
      }
    }

    @particle_system.update(scaled_analysis)
    @geometry_morpher.update(scaled_analysis)
    scaled_analysis[:bloom_flash] = @bloom_flash
    @bloom_controller.update(scaled_analysis)
    @camera_controller.update(scaled_analysis)

    @particle_data = @particle_system.get_data
    @geometry_data = @geometry_morpher.get_data
    @bloom_data = @bloom_controller.get_data
    @camera_data = @camera_controller.get_data

    # impulse decay per frame
    @impulse_bass *= VisualizerPolicy::IMPULSE_DECAY_EFFECT
    @impulse_mid *= VisualizerPolicy::IMPULSE_DECAY_EFFECT
    @impulse_high *= VisualizerPolicy::IMPULSE_DECAY_EFFECT
    @impulse_overall *= VisualizerPolicy::IMPULSE_DECAY_EFFECT
    @bloom_flash *= VisualizerPolicy::IMPULSE_DECAY_EFFECT
  end
end
  
