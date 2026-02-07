require_relative 'frequency_mapper'

class AudioAnalyzer
  SAMPLE_RATE = 48000
  FFT_SIZE = 2048

  def initialize
    @frequency_mapper = FrequencyMapper.new
    @smoothed_bass = 0.0
    @smoothed_mid = 0.0
    @smoothed_high = 0.0
    @smoothing_factor = 0.85
  end

  def analyze(frequency_data)
    # Convert frequency data to array if needed
    freq_array = frequency_data.is_a?(Array) ? frequency_data : frequency_data.to_a

    return empty_analysis if freq_array.empty?

    # Split into frequency bands
    bands = @frequency_mapper.split_bands(freq_array)

    # Calculate energy for each band
    bass_energy = calculate_energy(bands[:bass])
    mid_energy = calculate_energy(bands[:mid])
    high_energy = calculate_energy(bands[:high])
    overall_energy = calculate_energy(freq_array)

    # Apply smoothing to reduce jitter
    @smoothed_bass = lerp(@smoothed_bass, bass_energy, 1.0 - @smoothing_factor)
    @smoothed_mid = lerp(@smoothed_mid, mid_energy, 1.0 - @smoothing_factor)
    @smoothed_high = lerp(@smoothed_high, high_energy, 1.0 - @smoothing_factor)

    {
      bass: @smoothed_bass,
      mid: @smoothed_mid,
      high: @smoothed_high,
      overall_energy: overall_energy,
      dominant_frequency: find_dominant_frequency(freq_array),
      bands: {
        bass: bands[:bass],
        mid: bands[:mid],
        high: bands[:high]
      }
    }
  end

  private

  def calculate_energy(data)
    return 0.0 if data.empty?

    # Calculate RMS (root mean square) energy
    sum = 0.0
    data.each do |val|
      normalized = val.to_f / 255.0
      sum += normalized * normalized
    end

    Math.sqrt(sum / data.length)
  end

  def find_dominant_frequency(data)
    return 0 if data.empty?

    max_index = 0
    max_value = 0
    data.each_with_index do |val, idx|
      if val > max_value
        max_value = val
        max_index = idx
      end
    end

    # Convert bin index to frequency (Hz)
    max_index * (SAMPLE_RATE / 2.0) / (FFT_SIZE / 2.0)
  end

  def lerp(a, b, t)
    a + (b - a) * t
  end

  def empty_analysis
    {
      bass: 0.0,
      mid: 0.0,
      high: 0.0,
      overall_energy: 0.0,
      dominant_frequency: 0,
      bands: {
        bass: [],
        mid: [],
        high: []
      }
    }
  end
end
