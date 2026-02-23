# SynthEngine: Polyphonic synthesizer state management.
# Receives frequency/duty from serial input (UART RX) and manages a voice pool.
# Each voice is an independent oscillator with ADSR envelope.
# All voices share a master effects chain managed by SynthEffects.
# Pure Ruby state - delegates audio output to JavaScript via JSBridge.
class SynthEngine
  WAVEFORMS = %i[sine square sawtooth triangle].freeze

  ATTACK_MIN = 0.001;      ATTACK_MAX = 5.0
  DECAY_MIN = 0.001;       DECAY_MAX = 5.0
  SUSTAIN_MIN = 0.0;       SUSTAIN_MAX = 1.0
  RELEASE_MIN = 0.001;     RELEASE_MAX = 5.0
  GAIN_MIN = 0.0;          GAIN_MAX = 1.0
  MAX_VOICES_MIN = 1;      MAX_VOICES_MAX = 16
  MAX_SUSTAIN_MS_MIN = 50; MAX_SUSTAIN_MS_MAX = 10000

  DEFAULT_GAIN = 0.3
  DEFAULT_MAX_VOICES = 8
  DEFAULT_MAX_SUSTAIN_MS = 500

  attr_reader :waveform, :attack, :decay, :sustain, :release, :gain
  attr_reader :max_voices, :max_sustain_ms, :duty

  def initialize
    @waveform        = :sawtooth
    @attack          = 0.01
    @decay           = 0.3
    @sustain         = 0.6
    @release         = 0.3
    @gain            = DEFAULT_GAIN
    @max_voices      = DEFAULT_MAX_VOICES
    @max_sustain_ms  = DEFAULT_MAX_SUSTAIN_MS
    @duty            = 0
    @voices          = {}
    @next_voice_id   = 0
    @pending_voice_events   = []
    @pending_params_update  = true  # send initial params to JS on first frame
    @pending_voices_update  = false
    @last_note_on_ms = nil
  end

  def active?
    @voices.any? { |_id, v| v[:state] == :active }
  end

  def voice_count
    @voices.count { |_id, v| v[:state] == :active }
  end

  # --- UART RX compatible interface (note_on/note_off) ---

  def note_on(freq, duty, now_ms: nil)
    f = clamp(freq.to_i, SerialProtocol::FREQ_MIN, SerialProtocol::FREQ_MAX)
    d = clamp(duty.to_i, SerialProtocol::DUTY_MIN, SerialProtocol::DUTY_MAX)

    if f == 0 || d == 0
      note_off
      return
    end

    @last_note_on_ms = now_ms || (Time.now.to_f * 1000)
    @duty = d

    # Same frequency already active: no new voice needed
    return if @voices.any? { |_id, v| v[:freq] == f && v[:state] == :active }

    # Different frequency: release all active voices so previous pitch fades out via ADSR
    # (sensor sends continuous pitch data — one pitch at a time, not chords)
    @voices.select { |_id, v| v[:state] == :active }.each { |id, _v| release_voice(id) }

    voice_id = alloc_voice_id
    @voices[voice_id] = { freq: f, duty: d, state: :active }
    @pending_voice_events << { type: :note_on, voice_id: voice_id, freq: f, duty: d }
    @pending_voices_update = true
  end

  def note_off
    @voices.select { |_id, v| v[:state] == :active }.each do |id, _v|
      release_voice(id)
    end
  end

  # --- Waveform ---

  def set_waveform(type)
    sym = type.to_s.to_sym
    raise ArgumentError, "Invalid waveform: #{type}" unless WAVEFORMS.include?(sym)
    @waveform = sym
    @pending_params_update = true
  end

  # --- ADSR Envelope ---

  def set_attack(val)
    @attack = clamp(val.to_f, ATTACK_MIN, ATTACK_MAX)
    @pending_params_update = true
  end

  def set_decay(val)
    @decay = clamp(val.to_f, DECAY_MIN, DECAY_MAX)
    @pending_params_update = true
  end

  def set_sustain(val)
    @sustain = clamp(val.to_f, SUSTAIN_MIN, SUSTAIN_MAX)
    @pending_params_update = true
  end

  def set_release(val)
    @release = clamp(val.to_f, RELEASE_MIN, RELEASE_MAX)
    @pending_params_update = true
  end

  # --- Gain ---

  def set_gain(val)
    @gain = clamp(val.to_f, GAIN_MIN, GAIN_MAX)
    @pending_params_update = true
  end

  # --- Voice configuration ---

  def set_max_voices(val)
    @max_voices = clamp(val.to_i, MAX_VOICES_MIN, MAX_VOICES_MAX)
    @pending_params_update = true
  end

  def set_max_sustain_ms(val)
    @max_sustain_ms = clamp(val.to_i, MAX_SUSTAIN_MS_MIN, MAX_SUSTAIN_MS_MAX)
    @pending_params_update = true
  end

  # --- Serial receive timeout (auto note_off) ---

  def check_timeout(current_ms: nil, threshold_ms: SerialProtocol::RECEIVE_TIMEOUT_MS)
    return unless active?
    return unless @last_note_on_ms
    current_ms ||= (Time.now.to_f * 1000)
    note_off if (current_ms - @last_note_on_ms) > threshold_ms
  end

  # --- Pending update ---

  def pending_update?
    @pending_params_update || @pending_voices_update
  end

  def consume_update
    return nil unless pending_update?

    result = {}

    if @pending_params_update
      result[:params] = {
        waveform:       @waveform,
        attack:         @attack,
        decay:          @decay,
        sustain:        @sustain,
        release:        @release,
        gain:           @gain,
        max_sustain_ms: @max_sustain_ms,
      }
      @pending_params_update = false
    end

    if @pending_voices_update
      result[:voice_events] = @pending_voice_events.dup
      @pending_voice_events.clear
      @voices.reject! { |_id, v| v[:state] == :releasing }
      @pending_voices_update = false
    end

    result
  end

  def status
    state = active? ? "on(#{voice_count}v)" : "off"
    "synth: #{state} #{@waveform} duty=#{@duty}% " \
      "A:#{@attack} D:#{@decay} S:#{@sustain} R:#{@release} " \
      "gain=#{(@gain * 100).round}% voices=#{@max_voices} sustain_ms=#{@max_sustain_ms}"
  end

  private

  def alloc_voice_id
    id = @next_voice_id
    @next_voice_id = (@next_voice_id + 1) % 100000
    id
  end

  def release_voice(voice_id)
    return unless @voices[voice_id]
    @voices[voice_id][:state] = :releasing
    @pending_voice_events << { type: :note_off, voice_id: voice_id }
    @pending_voices_update = true
  end

  def clamp(val, min, max)
    [[val, min].max, max].min
  end
end
