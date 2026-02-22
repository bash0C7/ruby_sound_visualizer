# SynthEngine: State management for analog monophonic synthesizer.
# Receives frequency/duty from serial input (PicoRuby) and applies
# waveform selection, ADSR envelope, and filter parameters.
# Pure Ruby state - delegates audio output to JavaScript via JSBridge.
class SynthEngine
  WAVEFORMS = %i[sine square sawtooth triangle].freeze
  FILTER_TYPES = %i[lowpass highpass bandpass].freeze

  FREQ_MIN = 0
  FREQ_MAX = 20000
  DUTY_MIN = 0
  DUTY_MAX = 100

  ATTACK_MIN = 0.001
  ATTACK_MAX = 5.0
  DECAY_MIN = 0.001
  DECAY_MAX = 5.0
  SUSTAIN_MIN = 0.0
  SUSTAIN_MAX = 1.0
  RELEASE_MIN = 0.001
  RELEASE_MAX = 5.0

  FILTER_CUTOFF_MIN = 20.0
  FILTER_CUTOFF_MAX = 20000.0
  RESONANCE_MIN = 0.0
  RESONANCE_MAX = 30.0

  GAIN_MIN = 0.0
  GAIN_MAX = 1.0

  DEFAULT_GAIN = 0.3

  attr_reader :waveform, :attack, :decay, :sustain, :release
  attr_reader :filter_cutoff, :filter_resonance, :filter_type
  attr_reader :frequency, :duty, :gain

  def initialize
    @waveform = :sawtooth
    @attack = 0.01
    @decay = 0.3
    @sustain = 0.6
    @release = 0.3
    @filter_cutoff = 2000.0
    @filter_resonance = 1.0
    @filter_type = :lowpass
    @frequency = 0
    @duty = 0
    @gain = DEFAULT_GAIN
    @active = false
    @pending_update = false
  end

  def active?
    @active
  end

  # --- Waveform ---

  def set_waveform(type)
    sym = type.to_s.to_sym
    raise ArgumentError, "Invalid waveform: #{type}" unless WAVEFORMS.include?(sym)

    @waveform = sym
    @pending_update = true
  end

  # --- ADSR Envelope ---

  def set_attack(val)
    @attack = clamp(val.to_f, ATTACK_MIN, ATTACK_MAX)
    @pending_update = true
  end

  def set_decay(val)
    @decay = clamp(val.to_f, DECAY_MIN, DECAY_MAX)
    @pending_update = true
  end

  def set_sustain(val)
    @sustain = clamp(val.to_f, SUSTAIN_MIN, SUSTAIN_MAX)
    @pending_update = true
  end

  def set_release(val)
    @release = clamp(val.to_f, RELEASE_MIN, RELEASE_MAX)
    @pending_update = true
  end

  # --- Filter ---

  def set_filter_cutoff(val)
    @filter_cutoff = clamp(val.to_f, FILTER_CUTOFF_MIN, FILTER_CUTOFF_MAX)
    @pending_update = true
  end

  def set_filter_resonance(val)
    @filter_resonance = clamp(val.to_f, RESONANCE_MIN, RESONANCE_MAX)
    @pending_update = true
  end

  def set_filter_type(type)
    sym = type.to_s.to_sym
    raise ArgumentError, "Invalid filter type: #{type}" unless FILTER_TYPES.include?(sym)

    @filter_type = sym
    @pending_update = true
  end

  # --- Note on/off (from serial frequency data) ---

  def note_on(freq, duty)
    f = clamp(freq.to_i, FREQ_MIN, FREQ_MAX)
    d = clamp(duty.to_i, DUTY_MIN, DUTY_MAX)

    if f == 0 && d == 0
      note_off
      return
    end

    @frequency = f
    @duty = d
    @active = true
    @pending_update = true
  end

  def note_off
    @active = false
    @pending_update = true
  end

  # --- Gain ---

  def set_gain(val)
    @gain = clamp(val.to_f, GAIN_MIN, GAIN_MAX)
    @pending_update = true
  end

  # --- Pending update ---

  def pending_update?
    @pending_update
  end

  def consume_update
    return nil unless @pending_update

    @pending_update = false
    {
      waveform: @waveform,
      attack: @attack,
      decay: @decay,
      sustain: @sustain,
      release: @release,
      filter_cutoff: @filter_cutoff,
      filter_resonance: @filter_resonance,
      filter_type: @filter_type,
      frequency: @frequency,
      duty: @duty,
      active: @active,
      gain: @gain
    }
  end

  def status
    state = @active ? "on" : "off"
    "synth: #{state} #{@waveform} freq=#{@frequency}Hz duty=#{@duty}% " \
      "A:#{@attack} D:#{@decay} S:#{@sustain} R:#{@release} " \
      "cutoff=#{@filter_cutoff.round}Hz Q:#{@filter_resonance} " \
      "gain=#{(@gain * 100).round}%"
  end

  private

  def clamp(val, min, max)
    [[val, min].max, max].min
  end
end
