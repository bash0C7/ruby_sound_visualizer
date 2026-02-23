# SerialAudioSource: State management for serial-received PWM audio output.
# Receives frequency/duty data from PicoRuby via serial and tracks state
# for Web Audio API oscillator updates. Pure Ruby state - no JavaScript calls.
class SerialAudioSource
  DEFAULT_VOLUME = 0.1

  attr_reader :frequency, :duty, :volume

  def initialize
    @active = false
    @user_stopped = false
    @frequency = 440
    @duty = 50
    @volume = DEFAULT_VOLUME
    @pending_update = false
  end

  def active?
    @active
  end

  def start
    @user_stopped = false
    @active = true
    @pending_update = true
  end

  def stop
    @user_stopped = true
    @active = false
    @pending_update = true
  end

  # Update frequency and duty from received serial data.
  # Auto-starts on first call so PicoRuby button press triggers audio immediately.
  # Does NOT restart if user explicitly stopped via stop().
  def update(freq, duty)
    start unless @active || @user_stopped
    @frequency = [[freq.to_i, SerialProtocol::FREQ_MIN].max, SerialProtocol::FREQ_MAX].min
    @duty = [[duty.to_i, SerialProtocol::DUTY_MIN].max, SerialProtocol::DUTY_MAX].min
    @pending_update = true
  end

  def pending_update?
    @pending_update
  end

  # Consume pending update and return current state for JS bridge.
  def consume_update
    @pending_update = false
    { frequency: @frequency, duty: @duty, active: @active, volume: @volume }
  end

  def set_volume(vol)
    @volume = [[vol.to_f, 0.0].max, 1.0].min
    @pending_update = true
  end

  def status
    state = @active ? "on" : "off"
    "serial_audio: #{state} freq=#{@frequency}Hz duty=#{@duty}% vol=#{(@volume * 100).round}%"
  end
end
