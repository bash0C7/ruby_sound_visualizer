class BloomController
  def initialize
    @base_strength = 1.5
    @base_threshold = 0.0  # Allow all emissive materials to glow
    @strength = @base_strength
    @threshold = @base_threshold
  end

  def update(analysis)
    energy = analysis[:overall_energy]
    impulse = analysis[:impulse] || {}
    imp_overall = impulse[:overall] || 0.0

    # エネルギーに応じてBloom強度（ソフトクリッピングで飽和防止）
    @strength = @base_strength + Math.tanh(energy * 2.0) * 2.5
    # impulse フラッシュ（抑制付き）
    @strength += Math.tanh(imp_overall) * 1.5
    @strength = [@strength, 4.5].min

    # Threshold adjusted for VRM emissiveIntensity range (0.3-1.5)
    # Low energy: threshold ~0.15, High energy: threshold ~0.0
    # This allows bloom to work with lower emissive intensities
    @threshold = 0.15 - Math.tanh(energy) * 0.15
    @threshold -= 0.04 * imp_overall
    @threshold = [@threshold, 0.0].max
  end

  def get_data
    { strength: @strength, threshold: @threshold }
  end
end
  
