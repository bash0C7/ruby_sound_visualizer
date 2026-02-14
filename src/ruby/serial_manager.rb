# SerialManager: Ruby-side state machine for Web Serial communication.
# Manages connection state, TX queue, RX buffer, and baud rate.
# Actual serial I/O is delegated to JavaScript via JSBridge.
class SerialManager
  BAUD_RATES = [38400, 115200].freeze
  DEFAULT_BAUD = 115_200
  RX_LOG_MAX_LINES = 100
  TX_LOG_MAX_LINES = 50

  attr_reader :baud_rate, :rx_log, :tx_log, :rx_buffer

  def initialize
    @connected = false
    @baud_rate = DEFAULT_BAUD
    @rx_buffer = ''
    @rx_log = []
    @tx_log = []
  end

  # Connection state management (driven by JS callbacks)

  def connected?
    @connected
  end

  def on_connect(baud_rate)
    @baud_rate = baud_rate.to_i
    @connected = true
    @rx_buffer = ''
    "serial: connected at #{@baud_rate}bps"
  end

  def on_disconnect
    @connected = false
    @rx_buffer = ''
    "serial: disconnected"
  end

  # Baud rate selection

  def set_baud(rate)
    rate = rate.to_i
    unless BAUD_RATES.include?(rate)
      return "serial: invalid baud rate #{rate} (use #{BAUD_RATES.join('/')})"
    end
    return "serial: disconnect first to change baud rate" if @connected
    @baud_rate = rate
    "serial: baud rate set to #{@baud_rate}"
  end

  # Transmit: format data and queue for JS to send

  def send_text(text)
    return "serial: not connected" unless @connected
    return "serial: empty message" if text.nil? || text.strip.empty?

    log_tx(text.strip)
    text.strip
  end

  # Send audio analysis data as protocol frame
  def send_audio_frame(analysis)
    return nil unless @connected
    return nil unless analysis.is_a?(Hash)

    frame = SerialProtocol.encode(
      level: analysis[:overall_energy] || 0.0,
      bass: analysis[:bass] || 0.0,
      mid: analysis[:mid] || 0.0,
      high: analysis[:high] || 0.0
    )
    log_tx(frame.strip)
    frame
  end

  # Receive: accumulate data from JS and extract frames

  def receive_data(data)
    return unless data.is_a?(String) && !data.empty?

    @rx_buffer += data
    frames, @rx_buffer = SerialProtocol.extract_frames(@rx_buffer)

    # Log raw received data (line-by-line)
    data.split("\n").each do |line|
      next if line.strip.empty?
      log_rx(line.strip)
    end

    frames
  end

  # Log management

  def clear_rx_log
    @rx_log = []
    "serial: RX log cleared"
  end

  def clear_tx_log
    @tx_log = []
    "serial: TX log cleared"
  end

  def status
    state = @connected ? "connected" : "disconnected"
    "serial: #{state} #{@baud_rate}bps | RX:#{@rx_log.length} TX:#{@tx_log.length}"
  end

  private

  def log_rx(text)
    @rx_log << text
    @rx_log.shift while @rx_log.length > RX_LOG_MAX_LINES
  end

  def log_tx(text)
    @tx_log << text
    @tx_log.shift while @tx_log.length > TX_LOG_MAX_LINES
  end
end
