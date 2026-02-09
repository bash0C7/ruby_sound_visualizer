class ColorPalette
  @@hue_mode = nil  # nil = grayscale, 1,2,3 = 色相モード
  @@hue_offset = 0.0  # 手動オフセット（度数、0-360循環）
  @@last_hsv = [0, 0, 0.3]  # デバッグ用: 最後に計算した H, S, V

  def self.set_hue_mode(mode)
    @@hue_mode = mode
    @@hue_offset = 0.0  # プリセット選択時はオフセットリセット
  end

  def self.get_hue_mode
    @@hue_mode
  end

  def self.get_hue_offset
    @@hue_offset
  end

  def self.shift_hue_offset(delta)
    @@hue_offset = (@@hue_offset + delta) % 360.0
  end

  def self.get_last_hsv
    @@last_hsv
  end

  def self.frequency_to_color(analysis)
    bass = analysis[:bass]
    mid = analysis[:mid]
    high = analysis[:high]

    total = bass + mid + high

    if total < 0.01
      @@last_hsv = [0, 0, 0.3]
      return [0.3, 0.3, 0.3]
    end

    # 全モード統一：明度（ソフトクリッピングで大音量での飽和を防ぐ）
    value = 0.4 + Math.tanh(total * 0.5) * 0.3

    # 最大明度キャップ適用
    if defined?($max_lightness) && $max_lightness < 255
      max_v = $max_lightness / 255.0
      value = [value, max_v].min
    end

    # Grayscale mode
    if @@hue_mode.nil?
      @@last_hsv = [0, 0, value]
      return hsv_to_rgb(0, 0, value)
    end

    # 色相シフト: bass→低, mid→中, high→高 の重み付き
    # bass=0.0, mid=0.5, high=1.0 寄りにマッピング
    if total > 0.01
      hue_shift = (mid * 0.5 + high * 1.0) / total
    else
      hue_shift = 0.5
    end

    # モードに応じて色相範囲（各240度幅） + 手動オフセット
    offset = @@hue_offset / 360.0
    case @@hue_mode
    when 1
      # 赤中心: 240-120度 (マゼンタ←赤→黄→緑)
      hue = (0.667 + offset + hue_shift * 0.667) % 1.0
    when 2
      # 緑中心: 0-240度 (赤→黄→緑→シアン→青)
      hue = (offset + hue_shift * 0.667) % 1.0
    when 3
      # 青中心: 120-360度 (緑→シアン→青→紫→マゼンタ)
      hue = (0.333 + offset + hue_shift * 0.667) % 1.0
    else
      hue = 0
    end

    # 彩度: ソフトクリッピング
    saturation = 0.65 + Math.tanh(total * 0.5) * 0.15

    @@last_hsv = [hue, saturation, value]
    hsv_to_rgb(hue, saturation, value)
  end

  # 距離ベースの色計算（円状グラデーション用）
  # distance: 0.0（中心）〜 1.0（外縁）
  def self.frequency_to_color_at_distance(analysis, distance)
    bass = analysis[:bass]
    mid = analysis[:mid]
    high = analysis[:high]

    total = bass + mid + high
    return [0.3, 0.3, 0.3] if total < 0.01

    value = 0.4 + Math.tanh(total * 0.5) * 0.3

    # 最大明度キャップ適用
    if defined?($max_lightness) && $max_lightness < 255
      max_v = $max_lightness / 255.0
      value = [value, max_v].min
    end

    if @@hue_mode.nil?
      return hsv_to_rgb(0, 0, value)
    end

    # 距離で色相範囲内をグラデーション（各240度幅） + 手動オフセット
    offset = @@hue_offset / 360.0
    case @@hue_mode
    when 1
      hue = (0.667 + offset + distance * 0.667) % 1.0
    when 2
      hue = (offset + distance * 0.667) % 1.0
    when 3
      hue = (0.333 + offset + distance * 0.667) % 1.0
    else
      hue = 0
    end

    saturation = 0.65 + Math.tanh(total * 0.5) * 0.15

    hsv_to_rgb(hue, saturation, value)
  end

  def self.energy_to_brightness(energy)
    0.5 + (energy ** 0.4) * 2.5
  end

  private

  def self.hsv_to_rgb(h, s, v)
    c = v * s
    x = c * (1 - ((h * 6) % 2 - 1).abs)
    m = v - c

    r, g, b = case (h * 6).floor
    when 0 then [c, x, 0]
    when 1 then [x, c, 0]
    when 2 then [0, c, x]
    when 3 then [0, x, c]
    when 4 then [x, 0, c]
    else [c, 0, x]
    end

    [r + m, g + m, b + m]
  end
end
  
