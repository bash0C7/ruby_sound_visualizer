# Manages audio input state (microphone mute and source selection)
# Single source of truth for audio input configuration
# Pure Ruby state management - no JavaScript calls
class AudioInputManager
  attr_reader :source

  def initialize
    @mic_muted = false
    @source = :microphone  # :microphone or :tab
  end

  # === Mic mute control ===

  def mic_muted?
    @mic_muted
  end

  def mute_mic
    @mic_muted = true
  end

  def unmute_mic
    @mic_muted = false
  end

  def toggle_mic
    @mic_muted = !@mic_muted
  end

  # === Source switching ===

  def switch_to_tab
    @source = :tab
  end

  def switch_to_mic
    @source = :microphone
  end

  # === Query methods ===

  def tab_capture?
    @source == :tab
  end

  def mic_input?
    @source == :microphone
  end

  # === Volume calculation ===

  def mic_volume
    @mic_muted ? 0 : 1
  end
end
