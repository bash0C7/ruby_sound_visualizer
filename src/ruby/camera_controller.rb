class CameraController
  def initialize
    @base_position = [0, 0, 5]
    @shake_decay = 0.9
    @shake_offset = [0, 0, 0]
  end

  def update(analysis)
    bass = analysis[:bass]
    impulse = analysis[:impulse] || {}
    imp_bass = impulse[:bass] || 0.0

    # 低音でカメラシェイク（bass > 0.6 または impulse 発動中）
    if bass > 0.6 || imp_bass > 0.3
      # impulse で強度を連続補間（0.3 基準 + impulse で最大 0.3 追加）
      shake_intensity = bass * (0.3 + imp_bass * 0.3)
      @shake_offset = [
        (rand - 0.5) * shake_intensity,
        (rand - 0.5) * shake_intensity,
        (rand - 0.5) * shake_intensity * 0.5
      ]
    else
      # シェイクを徐々に減衰
      @shake_offset = @shake_offset.map { |s| s * @shake_decay }
    end
  end

  def get_data
    { position: @base_position, shake: @shake_offset }
  end
end
  
