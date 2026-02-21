# PicoRuby LED Visualizer for ATOM Matrix
# Receives audio analysis via USB Serial and renders on 5x5 WS2812 matrix.
#
# Serial protocol: <L:NNN,B:NNN,M:NNN,H:NNN>\n
# LED mapping: columns 0-1=bass(red), 2=mid(green), 3-4=high(blue)
# Brightness controlled by band magnitude.

require 'ws2812'
require 'uart'

LED_PIN = 27
LED_COUNT = 25
MATRIX_SIZE = 5
BAUD_RATE = 115_200

# Hue values (0-255 scale for HSB)
HUE_BASS = 0     # Red
HUE_MID  = 85    # Green
HUE_HIGH = 170   # Blue
SATURATION = 255

# Column-to-band mapping
# Columns 0,1 = Bass, Column 2 = Mid, Columns 3,4 = High
COLUMN_BAND = [:bass, :bass, :mid, :high, :high]

# Initialize hardware
uart = UART.new(unit: :ESP32_UART0, baudrate: BAUD_RATE)
led = WS2812.new(RMTDriver.new(LED_PIN))

# Parse a single byte value from "KEY:NNN" format
def parse_field(pair)
  key, val = pair.split(':')
  return nil unless key && val
  int_val = val.to_i
  return nil if int_val < 0 || int_val > 255
  [key, int_val]
end

# Parse a complete frame string into a hash
# Returns nil if frame is invalid
def parse_frame(frame)
  return nil unless frame.start_with?('<') && frame.end_with?('>')
  body = frame[1..-2]
  pairs = body.split(',')
  return nil unless pairs.length == 4

  values = {}
  pairs.each do |pair|
    result = parse_field(pair)
    return nil unless result
    key, val = result
    case key
    when 'L' then values[:level] = val
    when 'B' then values[:bass] = val
    when 'M' then values[:mid] = val
    when 'H' then values[:high] = val
    else return nil
    end
  end

  return nil unless values[:level] != nil && values[:bass] != nil && values[:mid] != nil && values[:high] != nil
  values
end

# Map band to hue
def band_hue(band)
  case band
  when :bass then HUE_BASS
  when :mid  then HUE_MID
  when :high then HUE_HIGH
  else 0
  end
end

# Calculate LED brightness for a given row and band value
# Bottom rows light up first (like a VU meter)
def row_brightness(row, band_value, level)
  # row 0 = top (hardest to light), row 4 = bottom (easiest)
  threshold = (4 - row) * 51  # 0, 51, 102, 153, 204
  if band_value > threshold
    # Scale brightness by level (overall volume)
    raw = [(band_value - threshold) * 5, 255].min
    (raw * level / 255.0).to_i
  else
    0
  end
end

# Render audio data to LED matrix
def render_leds(led, data)
  MATRIX_SIZE.times do |row|
    MATRIX_SIZE.times do |col|
      idx = row * MATRIX_SIZE + col
      band = COLUMN_BAND[col]
      hue = band_hue(band)
      band_val = data[band] || 0
      brightness = row_brightness(row, band_val, data[:level] || 0)
      led.show_hsb_hex(idx, hue, SATURATION, brightness)
    end
  end
  led.show
end

# Clear all LEDs
def clear_leds(led)
  LED_COUNT.times { |i| led.show_hsb_hex(i, 0, 0, 0) }
  led.show
end

# Main loop: read serial, parse frames, render LEDs
rx_buffer = ''
last_data = { level: 0, bass: 0, mid: 0, high: 0 }

# Initial LED test: brief flash
LED_COUNT.times { |i| led.show_hsb_hex(i, 85, 255, 30) }
led.show
sleep_ms 500
clear_leds(led)

while true
  # Read available serial data
  while uart.bytes_available > 0
    byte = uart.read(1)
    next unless byte

    if byte == "\n" || byte == "\r"
      # Try to parse accumulated buffer as frame
      stripped = rx_buffer.strip
      unless stripped.empty?
        data = parse_frame(stripped)
        if data
          last_data = data
          render_leds(led, last_data)
        end
      end
      rx_buffer = ''
    else
      rx_buffer += byte
      # Safety: prevent buffer overflow
      rx_buffer = '' if rx_buffer.length > 64
    end
  end

  sleep_ms 1
end
