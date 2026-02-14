require_relative 'test_helper'

class TestVJPadSerial < Test::Unit::TestCase
  def setup
    JS.reset_global!
    VJPlugin.reset!
    # Re-register plugins cleared by reset
    require_relative '../src/ruby/plugins/vj_serial'
    @serial = SerialManager.new
    @pad = VJPad.new(nil, serial_manager: @serial)
  end

  # --- Serial availability ---

  def test_serial_commands_unavailable_without_manager
    pad = VJPad.new(nil)
    result = pad.exec("sc")
    assert result[:ok]
    assert_match(/not available/, result[:msg])
  end

  def test_serial_manager_accessible
    assert_not_nil @pad.serial_manager
    assert_instance_of SerialManager, @pad.serial_manager
  end

  # --- sc (connect) ---

  def test_sc_sends_connect_request
    result = @pad.exec("sc")
    assert result[:ok]
    assert_match(/connecting/, result[:msg])
    assert_match(/115200/, result[:msg])
  end

  # --- sd (disconnect) ---

  def test_sd_disconnects
    @serial.on_connect(115_200)
    result = @pad.exec("sd")
    assert result[:ok]
    assert_match(/disconnected/, result[:msg])
    assert_equal false, @serial.connected?
  end

  # --- sb (baud rate) ---

  def test_sb_getter
    result = @pad.exec("sb")
    assert result[:ok]
    assert_match(/115200/, result[:msg])
  end

  def test_sb_setter_valid
    result = @pad.exec("sb 38400")
    assert result[:ok]
    assert_match(/38400/, result[:msg])
    assert_equal 38_400, @serial.baud_rate
  end

  def test_sb_setter_invalid
    result = @pad.exec("sb 9600")
    assert result[:ok]
    assert_match(/invalid/, result[:msg])
  end

  # --- ss (send text) ---

  def test_ss_sends_when_connected
    @serial.on_connect(115_200)
    result = @pad.exec('ss "hello world"')
    assert result[:ok]
    assert_match(/TX/, result[:msg])
  end

  def test_ss_fails_when_disconnected
    result = @pad.exec('ss "hello"')
    assert result[:ok]
    assert_match(/not connected/, result[:msg])
  end

  # --- sr (receive log) ---

  def test_sr_shows_empty_log
    result = @pad.exec("sr")
    assert result[:ok]
    assert_match(/empty/, result[:msg])
  end

  def test_sr_shows_received_data
    @serial.on_connect(115_200)
    @serial.receive_data("test data\n")
    result = @pad.exec("sr")
    assert result[:ok]
    assert_match(/test data/, result[:msg])
  end

  # --- st (transmit log) ---

  def test_st_shows_empty_log
    result = @pad.exec("st")
    assert result[:ok]
    assert_match(/empty/, result[:msg])
  end

  def test_st_shows_transmitted_data
    @serial.on_connect(115_200)
    @serial.send_text("outgoing")
    result = @pad.exec("st")
    assert result[:ok]
    assert_match(/outgoing/, result[:msg])
  end

  # --- si (status) ---

  def test_si_shows_status
    result = @pad.exec("si")
    assert result[:ok]
    assert_match(/disconnected/, result[:msg])
  end

  def test_si_shows_connected_status
    @serial.on_connect(38_400)
    result = @pad.exec("si")
    assert result[:ok]
    assert_match(/connected/, result[:msg])
    assert_match(/38400/, result[:msg])
  end

  # --- sa (auto send) ---

  def test_sa_getter_default_off
    result = @pad.exec("sa")
    assert result[:ok]
    assert_match(/off/, result[:msg])
  end

  def test_sa_enable
    result = @pad.exec("sa 1")
    assert result[:ok]
    assert_match(/on/, result[:msg])
    assert_equal true, @pad.serial_auto_send?
  end

  def test_sa_disable
    @pad.exec("sa 1")
    result = @pad.exec("sa 0")
    assert result[:ok]
    assert_match(/off/, result[:msg])
    assert_equal false, @pad.serial_auto_send?
  end

  # --- scl (clear logs) ---

  def test_scl_clears_all_logs
    @serial.on_connect(115_200)
    @serial.receive_data("rx data\n")
    @serial.send_text("tx data")
    result = @pad.exec("scl")
    assert result[:ok]
    assert_equal 0, @serial.rx_log.length
    assert_equal 0, @serial.tx_log.length
  end

  def test_scl_clears_rx_only
    @serial.on_connect(115_200)
    @serial.receive_data("rx data\n")
    @serial.send_text("tx data")
    @pad.exec('scl "rx"')
    assert_equal 0, @serial.rx_log.length
    assert_equal 1, @serial.tx_log.length
  end

  def test_scl_clears_tx_only
    @serial.on_connect(115_200)
    @serial.receive_data("rx data\n")
    @serial.send_text("tx data")
    @pad.exec('scl "tx"')
    assert_equal 1, @serial.rx_log.length
    assert_equal 0, @serial.tx_log.length
  end
end
