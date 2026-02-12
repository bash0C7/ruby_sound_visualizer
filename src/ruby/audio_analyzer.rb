class AudioAnalyzer
  def initialize
    @frequency_mapper = FrequencyMapper.new

    # Beat detection smoothing (fast response)
    @smoothed_bass = 0.0
    @smoothed_mid = 0.0
    @smoothed_high = 0.0

    # Visual smoothing (slow response, smooth motion)
    @visual_bass = 0.0
    @visual_mid = 0.0
    @visual_high = 0.0
    @visual_overall = 0.0

    # Impulse values (spike on beat detection, decay over time)
    @impulse_overall = 0.0
    @impulse_bass = 0.0
    @impulse_mid = 0.0
    @impulse_high = 0.0

    # ビート検出用: エネルギー履歴（リングバッファ）
    @energy_history = Array.new(VisualizerPolicy::HISTORY_SIZE, 0.0)
    @bass_history = Array.new(VisualizerPolicy::HISTORY_SIZE, 0.0)
    @mid_history = Array.new(VisualizerPolicy::HISTORY_SIZE, 0.0)
    @high_history = Array.new(VisualizerPolicy::HISTORY_SIZE, 0.0)
    @history_index = 0

    # ベースライン（環境ノイズレベル）の追跡
    @baseline_bass = 0.0
    @baseline_mid = 0.0
    @baseline_high = 0.0
    @warmup_remaining = VisualizerPolicy::WARMUP_FRAMES

    # ビート状態
    @beat_overall = false
    @beat_bass = false
    @beat_mid = false
    @beat_high = false
    @beat_cooldown = 0  # 連続検出防止
  end

  def analyze(frequency_data, sensitivity = 1.0)
    freq_array = frequency_data.is_a?(Array) ? frequency_data : frequency_data.to_a

    return empty_analysis if freq_array.empty?

    bands = @frequency_mapper.split_bands(freq_array)

    bass_energy = calculate_energy(bands[:bass])
    mid_energy = calculate_energy(bands[:mid])
    high_energy = calculate_energy(bands[:high])
    overall_energy = calculate_energy(freq_array)

    # Beat detection smoothing (fast response for accurate beat detection)
    @smoothed_bass = lerp(@smoothed_bass, bass_energy, 1.0 - VisualizerPolicy::AUDIO_SMOOTHING_FACTOR)
    @smoothed_mid = lerp(@smoothed_mid, mid_energy, 1.0 - VisualizerPolicy::AUDIO_SMOOTHING_FACTOR)
    @smoothed_high = lerp(@smoothed_high, high_energy, 1.0 - VisualizerPolicy::AUDIO_SMOOTHING_FACTOR)

    # Visual smoothing (slow response for smooth visuals, no sudden jumps)
    @visual_bass = lerp(@visual_bass, bass_energy, 1.0 - VisualizerPolicy::VISUAL_SMOOTHING_FACTOR)
    @visual_mid = lerp(@visual_mid, mid_energy, 1.0 - VisualizerPolicy::VISUAL_SMOOTHING_FACTOR)
    @visual_high = lerp(@visual_high, high_energy, 1.0 - VisualizerPolicy::VISUAL_SMOOTHING_FACTOR)
    @visual_overall = lerp(@visual_overall, overall_energy, 1.0 - VisualizerPolicy::VISUAL_SMOOTHING_FACTOR)

    # Exponential decay for noise reduction (natural decay, no hard cut)
    @visual_bass = exponential_decay(@visual_bass)
    @visual_mid = exponential_decay(@visual_mid)
    @visual_high = exponential_decay(@visual_high)
    @visual_overall = exponential_decay(@visual_overall)

    # ビート検出（ベースライン適応型 + sensitivity 適用）
    detect_beats(overall_energy, bass_energy, mid_energy, high_energy, sensitivity)

    # Generate impulse spikes on beat detection (decay over time)
    update_impulses

    # 履歴に記録
    @energy_history[@history_index] = overall_energy
    @bass_history[@history_index] = bass_energy
    @mid_history[@history_index] = mid_energy
    @high_history[@history_index] = high_energy
    @history_index = (@history_index + 1) % VisualizerPolicy::HISTORY_SIZE

    {
      bass: @visual_bass,           # Use visual values for smooth motion
      mid: @visual_mid,
      high: @visual_high,
      overall_energy: @visual_overall,
      dominant_frequency: find_dominant_frequency(freq_array),
      beat: {
        overall: @beat_overall,
        bass: @beat_bass,
        mid: @beat_mid,
        high: @beat_high
      },
      impulse: {                    # Impulse for instantaneous reactions
        overall: @impulse_overall,
        bass: @impulse_bass,
        mid: @impulse_mid,
        high: @impulse_high
      },
      bands: {
        bass: bands[:bass],
        mid: bands[:mid],
        high: bands[:high]
      }
    }
  end

  private

  def detect_beats(overall, bass, mid, high, sensitivity)
    # クールダウン中はビートを検出しない
    if @beat_cooldown > 0
      @beat_cooldown -= 1
      @beat_overall = false
      @beat_bass = false
      @beat_mid = false
      @beat_high = false
      # クールダウン中もベースラインは更新（遅い追従）
      update_baseline(bass, mid, high, VisualizerPolicy::BASELINE_RATE)
      return
    end

    # ウォームアップ中: ベースラインのキャリブレーションのみ
    if @warmup_remaining > 0
      @warmup_remaining -= 1
      update_baseline(bass, mid, high, VisualizerPolicy::WARMUP_RATE)
      @beat_overall = false
      @beat_bass = false
      @beat_mid = false
      @beat_high = false
      return
    end

    # ベースライン（環境ノイズレベル）を移動平均で更新
    # ビート中はベースラインを上げない（ビート値で汚染されるのを防ぐ）
    unless @beat_overall
      update_baseline(bass, mid, high, VisualizerPolicy::BASELINE_RATE)
    end

    # ベースラインからの偏差に sensitivity を適用
    bass_dev = (bass - @baseline_bass) * sensitivity
    mid_dev = (mid - @baseline_mid) * sensitivity
    high_dev = (high - @baseline_high) * sensitivity

    # バスドラム（bass）を主軸にビート検出
    # 条件: ベースラインからの偏差が閾値以上 かつ 絶対値も最低レベル以上
    @beat_bass = bass_dev > VisualizerPolicy::BEAT_BASS_DEVIATION && bass > VisualizerPolicy::BEAT_MIN_BASS
    @beat_mid = mid_dev > VisualizerPolicy::BEAT_MID_DEVIATION && mid > VisualizerPolicy::BEAT_MIN_MID
    @beat_high = high_dev > VisualizerPolicy::BEAT_HIGH_DEVIATION && high > VisualizerPolicy::BEAT_MIN_HIGH

    # overall は bass（バスドラム）がメイン。mid+high は補助的
    @beat_overall = @beat_bass

    # ビート検出時はクールダウン（連続検出防止: 約3フレーム）
    if @beat_overall || @beat_bass
      @beat_cooldown = 3
    end
  end

  def update_baseline(bass, mid, high, rate)
    @baseline_bass = lerp(@baseline_bass, bass, rate)
    @baseline_mid = lerp(@baseline_mid, mid, rate)
    @baseline_high = lerp(@baseline_high, high, rate)
  end

  def average(history)
    sum = 0.0
    history.each { |v| sum += v }
    sum / history.length
  end

  def calculate_energy(data)
    return 0.0 if data.empty?

    sum = 0.0
    data.each do |val|
      normalized = val.to_f / 255.0
      sum += normalized * normalized
    end

    Math.sqrt(sum / data.length)
  end

  def find_dominant_frequency(data)
    return 0 if data.nil? || data.length == 0

    max_index = 0
    max_value = 0

    data.length.times do |idx|
      val = data[idx].to_i
      if val > max_value
        max_value = val
        max_index = idx
      end
    end

    max_index * (VisualizerPolicy::SAMPLE_RATE / 2.0) / (VisualizerPolicy::FFT_SIZE / 2.0)
  end

  def lerp(a, b, t)
    a + (b - a) * t
  end

  def exponential_decay(value)
    # Apply exponential decay for values below threshold (natural noise reduction)
    # This avoids hard-cut noise gate and provides smooth decay to zero
    if value < VisualizerPolicy::EXPONENTIAL_THRESHOLD
      # Quadratic decay: value^2 / threshold (approaches 0 smoothly)
      value * value / VisualizerPolicy::EXPONENTIAL_THRESHOLD
    else
      value
    end
  end

  def update_impulses
    # Generate impulse spike on beat detection, then decay exponentially
    # Impulse provides instantaneous reactions while visual values stay smooth

    if @beat_bass
      @impulse_bass = 1.0
    else
      @impulse_bass *= VisualizerPolicy::IMPULSE_DECAY_AUDIO
    end

    if @beat_mid
      @impulse_mid = 1.0
    else
      @impulse_mid *= VisualizerPolicy::IMPULSE_DECAY_AUDIO
    end

    if @beat_high
      @impulse_high = 1.0
    else
      @impulse_high *= VisualizerPolicy::IMPULSE_DECAY_AUDIO
    end

    if @beat_overall
      @impulse_overall = 1.0
    else
      @impulse_overall *= VisualizerPolicy::IMPULSE_DECAY_AUDIO
    end
  end

  def empty_analysis
    {
      bass: 0.0,
      mid: 0.0,
      high: 0.0,
      overall_energy: 0.0,
      dominant_frequency: 0,
      beat: {
        overall: false,
        bass: false,
        mid: false,
        high: false
      },
      impulse: {
        overall: 0.0,
        bass: 0.0,
        mid: 0.0,
        high: 0.0
      },
      bands: {
        bass: [],
        mid: [],
        high: []
      }
    }
  end
end
  
