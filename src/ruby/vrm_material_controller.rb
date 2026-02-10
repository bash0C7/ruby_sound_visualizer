# VRMMaterialController
#
# Controls VRM model material properties for bloom effect.
# Calculates emissive intensity based on audio energy to make
# the entire VRM model glow naturally.
#
# Usage:
#   controller = VRMMaterialController.new
#   config = controller.apply_emissive(audio_analysis[:overall_energy])
#   # => { intensity: 1.5, color: [1.0, 1.0, 1.0] }
#
class VRMMaterialController
  # Base emissive intensity at zero energy
  # Low value to prevent over-glow at silence (works with white emissive)
  DEFAULT_BASE_EMISSIVE_INTENSITY = 0.2

  # Maximum emissive intensity at full energy
  # Moderate value to produce visible bloom without whiteout (with white emissive)
  MAX_EMISSIVE_INTENSITY = 1.0

  # Emissive color (white for natural glow)
  EMISSIVE_COLOR = [1.0, 1.0, 1.0].freeze

  def initialize
    # No state needed for now
  end

  # Calculates emissive intensity based on audio energy
  #
  # @param energy [Float] Overall audio energy (0.0-1.0)
  # @return [Float] Emissive intensity (1.0-2.5)
  def calculate_emissive_intensity(energy)
    # Clamp energy to valid range
    clamped_energy = [[energy, 0.0].max, 1.0].min

    # Linear interpolation between base and max intensity
    # energy = 0.0 -> intensity = 1.0
    # energy = 1.0 -> intensity = 2.5
    intensity = DEFAULT_BASE_EMISSIVE_INTENSITY +
                (clamped_energy * (MAX_EMISSIVE_INTENSITY - DEFAULT_BASE_EMISSIVE_INTENSITY))

    intensity
  end

  # Generates material configuration for VRM bloom effect
  #
  # @param energy [Float] Overall audio energy (0.0-1.0)
  # @return [Hash] Material config with :intensity and :color
  def apply_emissive(energy)
    {
      intensity: calculate_emissive_intensity(energy),
      color: EMISSIVE_COLOR.dup
    }
  end
end
