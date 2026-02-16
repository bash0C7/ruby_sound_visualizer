class BloomController
  def initialize
    @strength = VisualizerPolicy.bloom_base_strength
    @threshold = VisualizerPolicy::BLOOM_BASE_THRESHOLD
  end

  def update(analysis)
    energy = analysis[:overall_energy]
    impulse = analysis[:impulse] || {}
    imp_overall = impulse[:overall] || 0.0

    @strength = VisualizerPolicy.bloom_base_strength + Math.tanh(energy * VisualizerPolicy.bloom_energy_scale) * 2.5
    @strength += Math.tanh(imp_overall) * VisualizerPolicy.bloom_impulse_scale
    bloom_flash = analysis[:bloom_flash] || 0.0
    @strength += bloom_flash * 2.0 if bloom_flash > 0.01
    @strength = VisualizerPolicy.cap_bloom(@strength)

    @threshold = 0.15 - Math.tanh(energy) * 0.15
    @threshold -= 0.04 * imp_overall
    @threshold = [@threshold, VisualizerPolicy::BLOOM_MIN_THRESHOLD].max
  end

  def get_data
    { strength: @strength, threshold: @threshold }
  end
end
