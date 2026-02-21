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

# Complementary hue values (+128 on color wheel, mod 256)
HUE_BASS_C = 128    # Cyan (complement of Red)
HUE_MID_C  = 213    # Magenta (complement of Green)
HUE_HIGH_C = 42     # Yellow (complement of Blue)
COMPLEMENT_MAX = 45  # Max brightness for complementary color fill

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

# Map band to complementary hue
def complement_hue(band)
  case band
  when :bass then HUE_BASS_C
  when :mid  then HUE_MID_C
  when :high then HUE_HIGH_C
  else 128
  end
end

# Pack HSB into single integer for show_hsb_hex
# Format: (hue << 16) | (saturation << 8) | brightness
def pack_hsb(hue, saturation, brightness)
  (hue << 16) | (saturation << 8) | brightness
end

# Render audio data to LED matrix
# Signal rows: main color (red/green/blue) by band level
# Unlit rows: complementary color (cyan/magenta/yellow) as dim fill
def render_leds(led, data)
  colors = []
  level = data[:level] || 0
  MATRIX_SIZE.times do |row|
    threshold = (4 - row) * 51  # row 4=0, row 3=51, row 2=102, row 1=153, row 0=204
    MATRIX_SIZE.times do |col|
      band = COLUMN_BAND[col]
      band_val = data[band] || 0
      if band_val > threshold
        raw = [(band_val - threshold) * 5, 255].min
        brightness = (raw * level / 255.0).to_i
        colors << pack_hsb(band_hue(band), SATURATION, brightness)
      else
        comp_bri = (COMPLEMENT_MAX * level / 255.0).to_i
        colors << pack_hsb(complement_hue(band), SATURATION, comp_bri)
      end
    end
  end
  led.show_hsb_hex(*colors)
end

# Clear all LEDs
def clear_leds(led)
  led.show_hsb_hex(*Array.new(LED_COUNT, 0))
end

# Main loop: read serial, parse frames, render LEDs
rx_buffer = ''
last_data = { level: 0, bass: 0, mid: 0, high: 0 }

# Initial LED test: brief flash (green)
init_color = pack_hsb(85, 255, 30)
led.show_hsb_hex(*Array.new(LED_COUNT, init_color))
sleep_ms 500
clear_leds(led)

while true
  # Read available serial data
  while uart.bytes_available > 0
    byte = uart.read(1)
    next unless byte && byte.length == 1

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
