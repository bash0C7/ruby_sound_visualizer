class CameraController
  BASE_POSITION = [0, 0, 5].freeze
  SHAKE_DECAY = 0.9
  SHAKE_BASS_THRESHOLD = 0.6
  SHAKE_IMPULSE_THRESHOLD = 0.3
  SHAKE_Z_SCALE = 0.5

  def initialize
    @base_position = BASE_POSITION.dup
    @shake_offset = [0, 0, 0]
  end

  def update(analysis)
    bass = analysis[:bass]
    impulse = analysis[:impulse] || {}
    imp_bass = impulse[:bass] || 0.0

    if bass > SHAKE_BASS_THRESHOLD || imp_bass > SHAKE_IMPULSE_THRESHOLD
      shake_intensity = bass * (SHAKE_IMPULSE_THRESHOLD + imp_bass * SHAKE_IMPULSE_THRESHOLD)
      @shake_offset = [
        (rand - 0.5) * shake_intensity,
        (rand - 0.5) * shake_intensity,
        (rand - 0.5) * shake_intensity * SHAKE_Z_SCALE
      ]
    else
      @shake_offset = @shake_offset.map { |s| s * SHAKE_DECAY }
    end
  end

  def get_data
    { position: @base_position, shake: @shake_offset }
  end
end
