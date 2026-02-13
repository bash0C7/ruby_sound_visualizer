class BloomController
  def initialize
    @strength = VisualizerPolicy.bloom_base_strength
    @threshold = VisualizerPolicy::BLOOM_BASE_THRESHOLD
  end

  def update(analysis)
    energy = analysis[:overall_energy]
    impulse = analysis[:impulse] || {}
    imp_overall = impulse[:overall] || 0.0

    # エネルギーに応じてBloom強度（ソフトクリッピングで飽和防止）
    @strength = VisualizerPolicy.bloom_base_strength + Math.tanh(energy * VisualizerPolicy.bloom_energy_scale) * 2.5
    # impulse フラッシュ（抑制付き）
    @strength += Math.tanh(imp_overall) * VisualizerPolicy.bloom_impulse_scale
    # VJPad flash boost
    bloom_flash = analysis[:bloom_flash] || 0.0
    @strength += bloom_flash * 2.0 if bloom_flash > 0.01
    @strength = VisualizerPolicy.cap_bloom(@strength)

    # Threshold adjusted for VRM emissiveIntensity range (0.3-1.5)
    # Low energy: threshold ~0.15, High energy: threshold ~BLOOM_MIN_THRESHOLD
    # This allows bloom to work with lower emissive intensities
    @threshold = 0.15 - Math.tanh(energy) * 0.15
    @threshold -= 0.04 * imp_overall
    @threshold = [@threshold, VisualizerPolicy::BLOOM_MIN_THRESHOLD].max
  end

  def get_data
    { strength: @strength, threshold: @threshold }
  end
end
  
