class BloomController
  def initialize
    @base_strength = 1.5
    @base_threshold = 0.85
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

    # エネルギーが高いほどthresholdを下げる（下限付き、VRM白飛び防止のため0.3に）
    @threshold = 0.5 - Math.tanh(energy) * 0.15
    @threshold -= 0.04 * imp_overall
    @threshold = [@threshold, 0.3].max
  end

  def get_data
    { strength: @strength, threshold: @threshold }
  end
end
  
