class ParticleSystem
  def initialize
    @particles = Array.new(VisualizerPolicy::PARTICLE_COUNT) do
      range = VisualizerPolicy::PARTICLE_SPAWN_RANGE
      {
        position: [rand_range(-range, range), rand_range(-range, range), rand_range(-range, range)],
        velocity: [0, 0, 0],
        color: [0.3, 0.3, 0.3]  # dim gray (グレースケール起動)
      }
    end
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

    # ColorPalette から統一色を取得
    base_color = ColorPalette.frequency_to_color(analysis)

    # 最低明るさを保証 + ソフトクリッピングで大音量飽和防止
    brightness = 0.3 + Math.tanh(energy * 1.5) * 1.2
    # impulse で明度ブースト（抑制付き）
    brightness += 0.3 * imp_overall
    brightness = [brightness, 1.5].min

    # 動的爆発確率（20-70%、エネルギーに応じて変化）
    explosion_probability = VisualizerPolicy::PARTICLE_EXPLOSION_BASE_PROB + energy * VisualizerPolicy::PARTICLE_EXPLOSION_ENERGY_SCALE
    # 爆発力を強化（パーティクル数減で個別の動きを大きく）
    explosion_force = energy * VisualizerPolicy::PARTICLE_EXPLOSION_FORCE_SCALE

    # impulse で爆発確率と爆発力をブースト（連続的に減衰）
    explosion_probability = [explosion_probability + 0.3 * imp_overall, 0.9].min
    explosion_force += 0.35 * imp_overall

    @particles.each_with_index do |particle, idx|
      # パーティクルを3タイプに分類（0=bass, 1=mid, 2=high）
      freq_type = idx % 3

      case freq_type
      when 0  # 低音パーティクル: 放射状爆発
        trigger = bass > 0.4 || imp_bass > 0.3
        if trigger && rand < explosion_probability
          direction = normalize_vector(particle[:position])
          # impulse で力を連続補間（2.0 基準 + impulse で最大 1.0 追加）
          force = explosion_force * (2.0 + imp_bass * 1.0)
          particle[:velocity] = direction.map { |d| d * force }
        end

      when 1  # 中音パーティクル: 螺旋運動
        trigger = mid > 0.3 || imp_mid > 0.3
        if trigger && rand < explosion_probability * 0.8
          angle = rand * Math::PI * 2
          # impulse で力を連続補間（1.5 基準 + impulse で最大 1.0 追加）
          force = explosion_force * (1.5 + imp_mid * 1.0)
          particle[:velocity] = [
            Math.cos(angle) * force,
            force,
            Math.sin(angle) * force
          ]
        end

      when 2  # 高音パーティクル: 上向き噴出
        trigger = high > 0.3 || imp_high > 0.3
        if trigger && rand < explosion_probability * 0.7
          # impulse で力を連続補間（2.5 基準 + impulse で最大 1.0 追加）
          force = explosion_force * (2.5 + imp_high * 1.0)
          particle[:velocity] = [
            rand_range(-explosion_force, explosion_force) * 0.5,
            force,
            rand_range(-explosion_force, explosion_force) * 0.5
          ]
        end
      end

      # 色の適用（中心からの距離で円状グラデーション）
      pos = particle[:position]
      dist = Math.sqrt(pos[0]**2 + pos[1]**2 + pos[2]**2)
      normalized_dist = [dist / 10.0, 1.0].min  # 0.0(中心)〜1.0(外縁)
      dist_color = ColorPalette.frequency_to_color_at_distance(analysis, normalized_dist)
      # Apply brightness and max brightness cap (via VisualizerPolicy)
      color_with_brightness = dist_color.map { |c| [c * brightness, 0.0].max }
      particle[:color] = VisualizerPolicy.cap_rgb(*color_with_brightness)

      # 位置更新
      particle[:position][0] += particle[:velocity][0]
      particle[:position][1] += particle[:velocity][1]
      particle[:position][2] += particle[:velocity][2]

      # 摩擦（高速フェードアウトでビート感を出す）
      particle[:velocity][0] *= VisualizerPolicy::PARTICLE_FRICTION
      particle[:velocity][1] *= VisualizerPolicy::PARTICLE_FRICTION
      particle[:velocity][2] *= VisualizerPolicy::PARTICLE_FRICTION

      # 境界処理
      3.times do |i|
        if particle[:position][i].abs > VisualizerPolicy::PARTICLE_BOUNDARY
          range = VisualizerPolicy::PARTICLE_SPAWN_RANGE
          particle[:position][i] = rand_range(-range, range)
          particle[:velocity][i] = 0
        end
      end
    end
  end

  def get_data
    positions = []
    colors = []
    total_size = 0.0
    total_opacity = 0.0

    @particles.each do |p|
      positions.concat(p[:position])
      colors.concat(p[:color])

      # サイズを動的計算（パーティクル数減に合わせて2.5倍サイズアップ）
      brightness = (p[:color][0] + p[:color][1] + p[:color][2]) / 3.0
      size = (0.05 + brightness * 0.25) * 2.5
      total_size += size

      # 透明度を動的計算
      opacity = (0.6 + brightness * 0.4)
      opacity = [opacity, 1.0].min
      total_opacity += opacity
    end

    # 平均値を Ruby で計算（JavaScript 側の負荷を減らす）
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
  
