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

    if bass > 0.6 || imp_bass > 0.3
      shake_intensity = bass * (0.3 + imp_bass * 0.3)
      @shake_offset = [
        (rand - 0.5) * shake_intensity,
        (rand - 0.5) * shake_intensity,
        (rand - 0.5) * shake_intensity * 0.5
      ]
    else
      @shake_offset = @shake_offset.map { |s| s * @shake_decay }
    end
  end

  def get_data
    { position: @base_position, shake: @shake_offset }
  end
end
