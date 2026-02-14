# Simple peak limiter to prevent sudden loud transients (hand claps, etc.)
# from causing visual whiteout. Uses soft-knee tanh compression with
# fast attack and slow release.
#
# Signal flow: energy_in → soft_limit → energy_out (capped near threshold)
# - Below threshold: pass through unchanged
# - Above threshold: tanh compression maps excess to (0..headroom)
#   where headroom = 1.0 - threshold, so max output asymptotes to 1.0
# - Gain reduction state provides smooth release after transients
class AudioLimiter
  attr_reader :gain_reduction

  DEFAULT_THRESHOLD = 0.85
  RELEASE_RATE = 0.05      # Gain recovery per frame (slow release)

  def initialize(threshold: DEFAULT_THRESHOLD)
    @threshold = [threshold, 0.01].max
    @gain_reduction = 1.0
  end

  # Process a single energy value through the limiter.
  # Returns the limited energy value (asymptotically approaches 1.0).
  def process(energy)
    energy = [energy, 0.0].max  # Clamp negative values

    if energy <= 0.0
      release
      return 0.0
    end

    # Soft-knee limiting using tanh
    if energy > @threshold
      # Above threshold: compress excess into headroom (threshold..1.0)
      # tanh(x/threshold) maps large excess smoothly to 0..1
      headroom = 1.0 - @threshold
      excess = energy - @threshold
      compressed = @threshold + Math.tanh(excess / @threshold) * headroom
      # Update gain reduction (fast attack)
      new_gr = compressed / energy
      @gain_reduction = [@gain_reduction, new_gr].min
      compressed
    else
      # Below threshold: pass through, but apply current gain reduction
      # for smooth transition after loud transient
      release
      energy * @gain_reduction
    end
  end

  # Process all bands at once with shared gain reduction state.
  # Input: { bass: Float, mid: Float, high: Float, overall: Float }
  # Returns: same structure with limited values
  def process_bands(bands)
    # Find peak across all bands to determine gain reduction
    peak = [bands[:bass], bands[:mid], bands[:high], bands[:overall]].max

    if peak > @threshold
      headroom = 1.0 - @threshold
      excess = peak - @threshold
      compressed_peak = @threshold + Math.tanh(excess / @threshold) * headroom
      new_gr = compressed_peak / peak
      @gain_reduction = [@gain_reduction, new_gr].min
    else
      release
    end

    # Apply gain reduction to all bands
    {
      bass: [bands[:bass] * @gain_reduction, 0.0].max,
      mid: [bands[:mid] * @gain_reduction, 0.0].max,
      high: [bands[:high] * @gain_reduction, 0.0].max,
      overall: [bands[:overall] * @gain_reduction, 0.0].max
    }
  end

  def reset
    @gain_reduction = 1.0
  end

  private

  def release
    # Slow release: gradually recover gain_reduction toward 1.0
    @gain_reduction = [@gain_reduction + RELEASE_RATE, 1.0].min
  end
end
