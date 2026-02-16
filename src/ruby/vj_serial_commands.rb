module VJSerialCommands
  def serial_manager
    @serial_manager
  end

  def serial_auto_send?
    @serial_auto_send
  end

  def sc
    return "serial: not available" unless @serial_manager
    baud = @serial_manager.baud_rate
    JS.global.serialConnect(baud)
    "serial: connecting at #{baud}bps..."
  end

  def sd
    return "serial: not available" unless @serial_manager
    JS.global.serialDisconnect()
    @serial_manager.on_disconnect
  end

  def ss(text = '')
    return "serial: not available" unless @serial_manager
    msg = @serial_manager.send_text(text.to_s)
    if msg && !msg.start_with?("serial:")
      JS.global.serialSend(msg)
      "serial TX: #{msg}"
    else
      msg
    end
  end

  def sr(count = 10)
    return "serial: not available" unless @serial_manager
    lines = @serial_manager.rx_log.last(count.to_i)
    return "serial RX: (empty)" if lines.empty?
    "serial RX:\n#{lines.join("\n")}"
  end

  def st(count = 10)
    return "serial: not available" unless @serial_manager
    lines = @serial_manager.tx_log.last(count.to_i)
    return "serial TX: (empty)" if lines.empty?
    "serial TX:\n#{lines.join("\n")}"
  end

  def sb(rate = :_get)
    return "serial: not available" unless @serial_manager
    if rate == :_get
      return "serial baud: #{@serial_manager.baud_rate}"
    end
    @serial_manager.set_baud(rate.to_i)
  end

  def si
    return "serial: not available" unless @serial_manager
    @serial_manager.status
  end

  def sa(val = :_get)
    return "serial: not available" unless @serial_manager
    if val == :_get
      return "serial auto: #{@serial_auto_send ? 'on' : 'off'}"
    end
    @serial_auto_send = val.to_i != 0
    "serial auto: #{@serial_auto_send ? 'on' : 'off'}"
  end

  def scl(target = 'all')
    return "serial: not available" unless @serial_manager
    case target.to_s
    when 'rx'
      @serial_manager.clear_rx_log
    when 'tx'
      @serial_manager.clear_tx_log
    else
      @serial_manager.clear_rx_log
      @serial_manager.clear_tx_log
      "serial: logs cleared"
    end
  end

  # --- Serial Audio Commands ---

  def sao(val = :_get)
    return "serial_audio: not available" unless @serial_audio_source
    if val == :_get
      return "serial_audio: #{@serial_audio_source.active? ? 'on' : 'off'}"
    end
    if val.to_i != 0
      @serial_audio_source.start
    else
      @serial_audio_source.stop
    end
    "serial_audio: #{@serial_audio_source.active? ? 'on' : 'off'}"
  end

  def sav(val = :_get)
    return "serial_audio: not available" unless @serial_audio_source
    if val == :_get
      return "serial_audio vol: #{(@serial_audio_source.volume * 100).round}%"
    end
    @serial_audio_source.set_volume(val.to_f / 100.0)
    "serial_audio vol: #{(@serial_audio_source.volume * 100).round}%"
  end

  def sai
    return "serial_audio: not available" unless @serial_audio_source
    @serial_audio_source.status
  end

  def sad
    return "serial_audio: not available" unless @serial_audio_source
    JS.global.showSerialAudioDevicePicker()
    "serial_audio: device picker opened"
  end
end
