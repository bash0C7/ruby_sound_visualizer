class BloomController
  def initialize
    @strength = VisualizerPolicy.bloom_base_strength
    @threshold = VisualizerPolicy::BLOOM_BASE_THRESHOLD
  end

  def update(analysis)
    energy = analysis[:overall_energy]
    impulse = analysis[:impulse] || {}
    imp_overall = impulse[:overall] || 0.0

    @strength = VisualizerPolicy.bloom_base_strength + Math.tanh(energy * VisualizerPolicy.bloom_energy_scale) * VisualizerPolicy.bloom_strength_scale
    @strength += Math.tanh(imp_overall) * VisualizerPolicy.bloom_impulse_scale
    bloom_flash = analysis[:bloom_flash] || 0.0
    @strength += bloom_flash * VisualizerPolicy.bloom_flash_multiplier if bloom_flash > 0.01
    @strength = [@strength, 0.0].max
    @strength = VisualizerPolicy.cap_bloom(@strength)

    @threshold = VisualizerPolicy::BLOOM_THRESHOLD_BASE - Math.tanh(energy) * VisualizerPolicy::BLOOM_THRESHOLD_BASE
    @threshold -= VisualizerPolicy::BLOOM_THRESHOLD_IMPULSE_SCALE * imp_overall
    @threshold = [@threshold, VisualizerPolicy::BLOOM_MIN_THRESHOLD].max
  end

  def get_data
    { strength: @strength, threshold: @threshold }
  end
end
