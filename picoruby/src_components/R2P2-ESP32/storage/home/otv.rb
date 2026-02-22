require 'ws2812'
require 'gpio'
require 'irq'
require 'uart'
require 'i2c'
require 'vl53l0x'

BAUD_RATE = 115_200

module Speaker
  def initialize_speaker(muted: true)
    @muted = muted
    @target_duty = 0
  end

  def frequency(f)
    set_frequency(f)
  end

  def duty(d)
    @target_duty = d
    set_duty(@muted ? 0 : d)
  end

  def toggle_mute
    @muted = !@muted
    set_duty(@muted ? 0 : @target_duty)
  end

  def muted?
    @muted
  end

  protected

  def set_frequency(f)
    # サブクラスで実装
  end

  def set_duty(d)
    # サブクラスで実装
  end
end

class UARTSender
  include Speaker

  def initialize(uart, param = {})
    initialize_speaker(muted: param[:muted] == false ? false : true)
    @uart = uart
    @last_freq = 0
    @last_duty = 50
  end

  protected

  def set_frequency(f)
    @last_freq = f
    @uart.write("<F:#{f},D:#{@last_duty}>\n")
  end

  def set_duty(d)
    @last_duty = d
    @uart.write("<F:#{@last_freq},D:#{d}>\n")
  end
end

class NoiseInstrument
  I2C_SDA_PIN = 25
  I2C_SCL_PIN = 21

  DIST_VALID_MIN = 20       # センサーが「信用できる」最小値(mm)
  DIST_VALID_MAX = 300     # センサーが「信用できる」最大値(mm)
  FREQ_MIN = 200            # 最低周波数(Hz)。
  FREQ_MAX = 1000           # 最高周波数(Hz)。

  BASE_DUTY = 40           # 基準duty比(%)
  DUTY_MIN = 25            # 最小duty比(%)
  DUTY_MAX = 60            # 最大duty比(%)

  DUTY_SMOOTH_FACTOR = 1                # duty変化の滑らかさ（即座反応）
  FADE_RATE = 0.2                       # ノイズ時のフェードアウト減衰率(20%/frame)
  DISTANCE_SMOOTH_ALPHA = 50             # EMA係数（整数演算用: 0-100）50=差分の50%追随

  attr_reader :current_freq, :current_duty, :distance

  def initialize(speaker, tof_sensor)
    @speaker = speaker
    @tof_sensor = tof_sensor

    @current_freq = FREQ_MIN
    @current_duty = 1
    @target_duty = 1
    @distance = DIST_VALID_MIN
    @prev_distance = DIST_VALID_MIN  # EMA用の前回値
    @prev_set_freq = nil  # 前回設定した周波数
    @prev_set_duty = nil  # 前回設定したduty
    @unstable_frames = 0  # ノイズフレームカウント

    @freq_ratio = FREQ_MAX.to_f / FREQ_MIN  # 周波数比率（対数スケール用）
    @dist_range = DIST_VALID_MAX - DIST_VALID_MIN
  end

  def update
    # 距離計測とフィルタリング
    raw_distance = @tof_sensor.read_distance

    # ノイズ判定：-1、DIST_VALID_MIN未満、DIST_VALID_MAX超
    if raw_distance < 0 || raw_distance < DIST_VALID_MIN || raw_distance > DIST_VALID_MAX
      @unstable_frames += 1
      # フェードアウト処理（段階的に音を消す）
      @target_duty = (@target_duty * (1.0 - FADE_RATE)).to_i.clamp(1, BASE_DUTY)
      return
    end

    # EMAで距離を平滑化（整数演算）
    delta = raw_distance - @prev_distance
    @distance = @prev_distance + (delta * DISTANCE_SMOOTH_ALPHA / 100)
    @prev_distance = @distance
    @unstable_frames = 0

    # 周波数計算：対数スケール（オクターブ感覚）
    # freq = FREQ_MIN * (FREQ_MAX / FREQ_MIN) ^ (distance_ratio)
    distance_ratio = (@distance - DIST_VALID_MIN).to_f / @dist_range
    @current_freq = (FREQ_MIN * (@freq_ratio ** distance_ratio)).to_i
    @target_duty = BASE_DUTY

    if @prev_set_freq != @current_freq
      @speaker.frequency(@current_freq)
      @prev_set_freq = @current_freq
    end

    @current_duty += (@target_duty - @current_duty) / DUTY_SMOOTH_FACTOR
    @current_duty = @current_duty.clamp(1, DUTY_MAX)

    if @prev_set_duty != @current_duty
      @speaker.duty(@current_duty)
      @prev_set_duty = @current_duty
    end
  end
end

class FreqIndicator
  LED_PIN    = 27
  LED_COUNT  = 25
  SATURATION = 255

  def initialize(led_strip)
    @led_strip = led_strip
    @colors = Array.new(LED_COUNT, 0)
  end

  def update(freq, muted)
    if muted
      # Muted: all LEDs dim gray (saturation=0, brightness=20)
      gray = (0 << 16) | (0 << 8) | 20
      @led_strip.show_hsb_hex(*Array.new(LED_COUNT, gray))
      return
    end

    freq_range = NoiseInstrument::FREQ_MAX - NoiseInstrument::FREQ_MIN
    ratio = (freq - NoiseInstrument::FREQ_MIN).to_f / freq_range
    ratio = ratio.clamp(0.0, 1.0)
    lit_count = (ratio * LED_COUNT).to_i
    lit_count = 1 if lit_count < 1  # always at least 1 LED while sending

    # hue: 85(green) at FREQ_MIN → 0(red) at FREQ_MAX
    hue = (85 - (85.0 * ratio)).to_i

    LED_COUNT.times do |i|
      @colors[i] = i < lit_count ? ((hue << 16) | (SATURATION << 8) | 80) : 0
    end
    @led_strip.show_hsb_hex(*@colors)
  end
end

uart = UART.new(unit: :ESP32_UART0, baudrate: BAUD_RATE)
sender = UARTSender.new(uart)

button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
indicator_strip = WS2812.new(RMTDriver.new(FreqIndicator::LED_PIN))

i2c_bus = I2C.new(unit: :ESP32_I2C0, frequency: 100_000, sda_pin: NoiseInstrument::I2C_SDA_PIN, scl_pin: NoiseInstrument::I2C_SCL_PIN)
sleep_ms(100)

tof_sensor = VL53L0X.new(i2c_bus)
sleep_ms(100)

instrument = NoiseInstrument.new(sender, tof_sensor)
freq_indicator = FreqIndicator.new(indicator_strip)

irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {spk: sender}) do |btn, ev, cap|
  cap[:spk].toggle_mute
end

loop_counter = 0

loop do
  IRQ.process

  # 毎フレーム distance を処理
  instrument.update

  if loop_counter % 4 == 0
    freq_indicator.update(instrument.current_freq, sender.muted?)
  end

  loop_counter += 1

end
