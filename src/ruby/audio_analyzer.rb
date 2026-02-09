class AudioAnalyzer
  SAMPLE_RATE = 48000
  FFT_SIZE = 2048
  HISTORY_SIZE = 43  # 約2秒分（~21fps想定）

  BASELINE_RATE = 0.02       # ベースライン追従速度（ゆっくり = 移動平均的）
  WARMUP_RATE = 0.15         # ウォームアップ中の高速追従
  WARMUP_FRAMES = 30         # 約1秒間はビート検出しない（キャリブレーション）

  # ビート検出閾値（ベースラインからの偏差）
  BEAT_BASS_DEVIATION = 0.06
  BEAT_MID_DEVIATION = 0.08
  BEAT_HIGH_DEVIATION = 0.08
  # 最低エネルギー（環境ノイズとの区別）
  BEAT_MIN_BASS = 0.25
  BEAT_MIN_MID = 0.20
  BEAT_MIN_HIGH = 0.20

  def initialize
    @frequency_mapper = FrequencyMapper.new
    @smoothed_bass = 0.0
    @smoothed_mid = 0.0
    @smoothed_high = 0.0
    @smoothing_factor = 0.55  # 高速反応でビート感を出す

    # ビート検出用: エネルギー履歴（リングバッファ）
    @energy_history = Array.new(HISTORY_SIZE, 0.0)
    @bass_history = Array.new(HISTORY_SIZE, 0.0)
    @mid_history = Array.new(HISTORY_SIZE, 0.0)
    @high_history = Array.new(HISTORY_SIZE, 0.0)
    @history_index = 0

    # ベースライン（環境ノイズレベル）の追跡
    @baseline_bass = 0.0
    @baseline_mid = 0.0
    @baseline_high = 0.0
    @warmup_remaining = WARMUP_FRAMES

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

    @smoothed_bass = lerp(@smoothed_bass, bass_energy, 1.0 - @smoothing_factor)
    @smoothed_mid = lerp(@smoothed_mid, mid_energy, 1.0 - @smoothing_factor)
    @smoothed_high = lerp(@smoothed_high, high_energy, 1.0 - @smoothing_factor)

    # ビート検出（ベースライン適応型 + sensitivity 適用）
    detect_beats(overall_energy, bass_energy, mid_energy, high_energy, sensitivity)

    # 履歴に記録
    @energy_history[@history_index] = overall_energy
    @bass_history[@history_index] = bass_energy
    @mid_history[@history_index] = mid_energy
    @high_history[@history_index] = high_energy
    @history_index = (@history_index + 1) % HISTORY_SIZE

    {
      bass: @smoothed_bass,
      mid: @smoothed_mid,
      high: @smoothed_high,
      overall_energy: overall_energy,
      dominant_frequency: find_dominant_frequency(freq_array),
      beat: {
        overall: @beat_overall,
        bass: @beat_bass,
        mid: @beat_mid,
        high: @beat_high
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
      update_baseline(bass, mid, high, BASELINE_RATE)
      return
    end

    # ウォームアップ中: ベースラインのキャリブレーションのみ
    if @warmup_remaining > 0
      @warmup_remaining -= 1
      update_baseline(bass, mid, high, WARMUP_RATE)
      @beat_overall = false
      @beat_bass = false
      @beat_mid = false
      @beat_high = false
      return
    end

    # ベースライン（環境ノイズレベル）を移動平均で更新
    # ビート中はベースラインを上げない（ビート値で汚染されるのを防ぐ）
    unless @beat_overall
      update_baseline(bass, mid, high, BASELINE_RATE)
    end

    # ベースラインからの偏差に sensitivity を適用
    bass_dev = (bass - @baseline_bass) * sensitivity
    mid_dev = (mid - @baseline_mid) * sensitivity
    high_dev = (high - @baseline_high) * sensitivity

    # バスドラム（bass）を主軸にビート検出
    # 条件: ベースラインからの偏差が閾値以上 かつ 絶対値も最低レベル以上
    @beat_bass = bass_dev > BEAT_BASS_DEVIATION && bass > BEAT_MIN_BASS
    @beat_mid = mid_dev > BEAT_MID_DEVIATION && mid > BEAT_MIN_MID
    @beat_high = high_dev > BEAT_HIGH_DEVIATION && high > BEAT_MIN_HIGH

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
      beat: {
        overall: false,
        bass: false,
        mid: false,
        high: false
      },
      bands: {
        bass: [],
        mid: [],
        high: []
      }
    }
  end
end
  
