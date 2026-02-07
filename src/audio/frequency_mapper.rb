class FrequencyMapper
  # Frequency ranges (Hz)
  BASS_RANGE = (0..250)        # Low frequencies
  MID_RANGE = (250..2000)      # Mid frequencies
  HIGH_RANGE = (2000..20000)   # High frequencies

  SAMPLE_RATE = 48000
  FFT_SIZE = 2048

  def initialize
    @bin_size = (SAMPLE_RATE / 2.0) / (FFT_SIZE / 2.0)
  end

  def split_bands(frequency_data)
    bass = extract_range(frequency_data, BASS_RANGE)
    mid = extract_range(frequency_data, MID_RANGE)
    high = extract_range(frequency_data, HIGH_RANGE)

    {
      bass: bass,
      mid: mid,
      high: high
    }
  end

  private

  def extract_range(data, freq_range, bin_size = nil)
    bin_size ||= @bin_size
    start_bin = (freq_range.begin / bin_size).floor
    end_bin = [(freq_range.end / bin_size).ceil, data.length - 1].min

    if start_bin < data.length && end_bin >= start_bin
      data[start_bin..end_bin].to_a
    else
      []
    end
  end
end
