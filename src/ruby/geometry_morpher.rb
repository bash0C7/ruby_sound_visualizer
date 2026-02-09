class GeometryMorpher
  def initialize
    @rotation = [0, 0, 0]
    @base_scale = 1.0
    @scale = 1.0
    @emissive_intensity = 0.0
    @color = [0.3, 0.3, 0.3]  # 初期値 dim gray
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

    # ColorPalette から色を取得
    @color = ColorPalette.frequency_to_color(analysis)

    # スケールを大幅に強化（最大3.5倍）
    @scale = @base_scale + energy * 2.5
    # impulse でスケールブースト（連続的に減衰）
    @scale += 0.8 * imp_overall

    # 回転速度（通常）
    @rotation[0] += bass * 0.15
    @rotation[1] += mid * 0.1
    @rotation[2] += high * 0.08

    # impulse で回転を加速（帯域別、連続的に減衰）
    @rotation[0] += 0.5 * imp_bass
    @rotation[1] += 0.4 * imp_mid
    @rotation[2] += 0.3 * imp_high

    # 発光強度（ソフトクリッピングでホワイトアウト防止）
    @emissive_intensity = Math.tanh(energy * 1.5) * 1.5
    @emissive_intensity += Math.tanh(imp_overall) * 0.8
    @emissive_intensity = [@emissive_intensity, 2.0].min
  end

  def get_data
    {
      scale: @scale,
      rotation: @rotation,
      emissive_intensity: @emissive_intensity,
      color: @color  # 新規追加
    }
  end
end
  
