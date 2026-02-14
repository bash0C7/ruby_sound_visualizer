require_relative 'test_helper'

class TestSerialManager < Test::Unit::TestCase
  def setup
    @manager = SerialManager.new
  end

  # --- Initial state ---

  def test_initial_state_disconnected
    assert_equal false, @manager.connected?
    assert_equal 115_200, @manager.baud_rate
    assert_equal [], @manager.rx_log
    assert_equal [], @manager.tx_log
  end

  # --- Connection state ---

  def test_on_connect_sets_connected
    @manager.on_connect(115_200)
    assert_equal true, @manager.connected?
    assert_equal 115_200, @manager.baud_rate
  end

  def test_on_connect_returns_status_message
    result = @manager.on_connect(38_400)
    assert_match(/connected/, result)
    assert_match(/38400/, result)
  end

  def test_on_disconnect_clears_connection
    @manager.on_connect(115_200)
    result = @manager.on_disconnect
    assert_equal false, @manager.connected?
    assert_match(/disconnected/, result)
  end

  def test_on_connect_clears_rx_buffer
    @manager.on_connect(115_200)
    @manager.receive_data("partial<L:")
    @manager.on_disconnect
    @manager.on_connect(115_200)
    assert_equal '', @manager.rx_buffer
  end

  # --- Baud rate ---

  def test_set_baud_valid_rate
    result = @manager.set_baud(38_400)
    assert_equal 38_400, @manager.baud_rate
    assert_match(/38400/, result)
  end

  def test_set_baud_invalid_rate
    result = @manager.set_baud(9600)
    assert_equal 115_200, @manager.baud_rate
    assert_match(/invalid/, result)
  end

  def test_set_baud_rejected_while_connected
    @manager.on_connect(115_200)
    result = @manager.set_baud(38_400)
    assert_equal 115_200, @manager.baud_rate
    assert_match(/disconnect first/, result)
  end

  # --- Send text ---

  def test_send_text_returns_message_when_connected
    @manager.on_connect(115_200)
    result = @manager.send_text("hello")
    assert_equal "hello", result
  end

  def test_send_text_logs_to_tx
    @manager.on_connect(115_200)
    @manager.send_text("test message")
    assert_equal 1, @manager.tx_log.length
    assert_equal "test message", @manager.tx_log[0]
  end

  def test_send_text_rejected_when_disconnected
    result = @manager.send_text("hello")
    assert_match(/not connected/, result)
  end

  def test_send_text_rejected_when_empty
    @manager.on_connect(115_200)
    result = @manager.send_text("")
    assert_match(/empty/, result)
  end

  def test_send_text_rejected_when_nil
    @manager.on_connect(115_200)
    result = @manager.send_text(nil)
    assert_match(/empty/, result)
  end

  # --- Send audio frame ---

  def test_send_audio_frame_when_connected
    @manager.on_connect(115_200)
    analysis = { overall_energy: 0.5, bass: 1.0, mid: 0.0, high: 0.75 }
    frame = @manager.send_audio_frame(analysis)
    assert_not_nil frame
    assert frame.start_with?('<')
    assert frame.include?('>')
  end

  def test_send_audio_frame_nil_when_disconnected
    analysis = { overall_energy: 0.5, bass: 1.0, mid: 0.0, high: 0.75 }
    assert_nil @manager.send_audio_frame(analysis)
  end

  def test_send_audio_frame_nil_for_invalid_input
    @manager.on_connect(115_200)
    assert_nil @manager.send_audio_frame("not a hash")
  end

  def test_send_audio_frame_logs_to_tx
    @manager.on_connect(115_200)
    analysis = { overall_energy: 0.5, bass: 1.0, mid: 0.0, high: 0.75 }
    @manager.send_audio_frame(analysis)
    assert_equal 1, @manager.tx_log.length
  end

  # --- Receive data ---

  def test_receive_data_extracts_valid_frames
    @manager.on_connect(115_200)
    frames = @manager.receive_data("<L:128,B:64,M:32,H:0>\n")
    assert_equal 1, frames.length
    assert_in_delta 0.502, frames[0][:level], 0.01
  end

  def test_receive_data_accumulates_partial_frames
    @manager.on_connect(115_200)
    frames1 = @manager.receive_data("<L:128,B:64")
    assert_equal 0, frames1.length

    frames2 = @manager.receive_data(",M:32,H:0>\n")
    assert_equal 1, frames2.length
  end

  def test_receive_data_logs_to_rx
    @manager.on_connect(115_200)
    @manager.receive_data("line1\nline2\n")
    assert_equal 2, @manager.rx_log.length
  end

  def test_receive_data_nil_for_nil_input
    @manager.on_connect(115_200)
    assert_nil @manager.receive_data(nil)
  end

  def test_receive_data_nil_for_empty_input
    @manager.on_connect(115_200)
    assert_nil @manager.receive_data("")
  end

  # --- Log management ---

  def test_clear_rx_log
    @manager.on_connect(115_200)
    @manager.receive_data("data\n")
    @manager.clear_rx_log
    assert_equal 0, @manager.rx_log.length
  end

  def test_clear_tx_log
    @manager.on_connect(115_200)
    @manager.send_text("hello")
    @manager.clear_tx_log
    assert_equal 0, @manager.tx_log.length
  end

  def test_rx_log_max_lines
    @manager.on_connect(115_200)
    110.times { |i| @manager.receive_data("line#{i}\n") }
    assert @manager.rx_log.length <= SerialManager::RX_LOG_MAX_LINES
  end

  def test_tx_log_max_lines
    @manager.on_connect(115_200)
    60.times { |i| @manager.send_text("msg#{i}") }
    assert @manager.tx_log.length <= SerialManager::TX_LOG_MAX_LINES
  end

  # --- Status ---

  def test_status_disconnected
    result = @manager.status
    assert_match(/disconnected/, result)
    assert_match(/115200/, result)
  end

  def test_status_connected
    @manager.on_connect(38_400)
    result = @manager.status
    assert_match(/connected/, result)
    assert_match(/38400/, result)
  end
end
