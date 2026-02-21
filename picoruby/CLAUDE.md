# PicoRuby - ATOM Matrix Audio LED Visualizer

PicoRuby firmware for M5Stack ATOM Matrix that receives audio analysis data via USB Serial and renders frequency band visualization on the 5x5 LED matrix using WS2812.

## Hardware

- **MCU**: ESP32-PICO-D4 (M5Stack ATOM Matrix)
- **LED**: 5x5 WS2812 matrix (GPIO 27, 25 LEDs)
- **USB Serial**: ESP32_UART0 (115200 baud default)
- **Button**: GPIO 39

## Serial Protocol

ASCII frame format received from browser visualizer:

```
<L:NNN,B:NNN,M:NNN,H:NNN>\n
```

- Start: `<`, End: `>`, Terminator: `\n`
- L = overall level (0-255), B = bass (0-255), M = mid (0-255), H = high (0-255)
- Each frame is self-contained (stateless, robust to mid-stream disconnect)

## LED Mapping

5x5 matrix LED layout (index 0 = top-left, row-major):

```
 0  1  2  3  4
 5  6  7  8  9
10 11 12 13 14
15 16 17 18 19
20 21 22 23 24
```

Visualization strategy:
- Column 0-1: Bass (red hue, H=0)
- Column 2: Mid (green hue, H=85)
- Column 3-4: High (blue hue, H=170)
- Brightness: proportional to band value (0-255)
- Level: controls overall brightness multiplier

## UART Reference

```ruby
uart = UART.new(unit: :ESP32_UART0, baudrate: 115200)
while true
  if uart.bytes_available > 0
    byte = uart.read(1)
    # process byte
  end
  sleep_ms 1
end
```

## WS2812 Reference

```ruby
require 'ws2812'
led = WS2812.new(RMTDriver.new(27))  # GPIO 27 for ATOM Matrix internal LEDs
led.show_hsb_hex(index, hue, saturation, brightness)
led.show  # flush to hardware
```

## PicoRuby Compatibility Restrictions

PicoRuby (mruby-based) has a limited subset of Ruby. Always check compatibility before use.

### Prohibited Methods / Syntax

| Feature | Status | Alternative |
|---------|--------|-------------|
| `defined?` | NOT supported | Use explicit nil check: `if var != nil` |
| `Hash#fetch` | NOT supported | Use `hash[key] \|\| default` |
| `String#reverse` | NOT supported | Manual loop |
| `String#rjust` | NOT supported | Manual padding with `" " * (n - str.length) + str` |
| Inline `rescue` | NOT supported | Use full `begin/rescue/end` block |
| `proc` / `lambda` | NOT supported | Use method definitions |
| `Comparable` module | NOT supported | Implement comparison methods directly |

### Safe Patterns

```ruby
# nil check (NOT defined?)
if value != nil
  # use value
end

# Hash default (NOT Hash#fetch)
result = hash[key] || "default"

# String padding (NOT rjust)
padded = (" " * (3 - val.to_s.length)) + val.to_s

# Error handling (NOT inline rescue)
begin
  risky_operation
rescue => e
  handle_error
end
```

### Build Verification

Human-operated: build PicoRuby firmware using R2P2 toolchain to verify syntax compatibility.
Syntax errors may only appear at build time, not from standard `ruby -c`.

## Build System

Build tasks are automated via `picoruby/Rakefile` (adapted from picoruby-ot).

### Rake Task Permissions

| Task | Permission | Reason |
|------|-----------|--------|
| `rake check_env` | Allowed | Read-only environment check |
| `rake monitor` | Allowed | Read-only serial output monitoring |
| `rake build` | Ask first | Time-consuming build operation |
| `rake cleanbuild` | Ask first | Destructive clean + build |
| `rake buildall` | Ask first | Setup + build (recommended for initial setup) |
| `rake flash` | Ask first | Hardware write operation |
| `rake init` | Denied | Contains `git reset --hard` operations |
| `rake update` | Denied | Contains `git reset --hard` operations |

### Build Workflow

```
src_components/R2P2-ESP32/storage/home/led_visualizer.rb  ← edit here (git-tracked)
  ↓ copy_source_components
components/R2P2-ESP32/storage/home/led_visualizer.rb
  ↓ picorbc (compile .rb → .mrb)
components/R2P2-ESP32/storage/home/app.mrb
  ↓ idf.py build (in components/R2P2-ESP32/)
  ↓ idf.py flash
ATOM Matrix ESP32
```

### Environment Requirements

- ESP-IDF: `$HOME/esp/esp-idf/`
- Homebrew OpenSSL: `/opt/homebrew/opt/openssl`
- Target: ESP32 (Xtensa architecture)

### Application Selection

Build a specific PicoRuby application by setting the `APP` environment variable:

```bash
# Specify the app name (required)
APP=led_visualizer rake build
APP=led_visualizer rake flash
APP=led_visualizer rake monitor
```

### Usage Examples

```bash
# Initial setup (setup_esp32 + build)
cd picoruby && APP=led_visualizer rake buildall

# Normal build workflow
cd picoruby && APP=led_visualizer rake build && rake flash && rake monitor

# Check environment
cd picoruby && rake check_env

# Clean rebuild
cd picoruby && APP=led_visualizer rake cleanbuild
```

## File Structure

```
picoruby/
  CLAUDE.md          # This file (project instructions)
  AGENTS.md          # Symlink to CLAUDE.md
  SERIAL_AUDIO_PROTOCOL.md  # Serial protocol spec
  Rakefile           # Build automation
  .claude/
    settings.local.json  # Rake command permissions
  src_components/    # Source components (git-tracked)
    R2P2-ESP32/
      sdkconfig.defaults
      storage/home/
        led_visualizer.rb    # Main firmware source (edit here)
      components/picoruby-esp32/
        CMakeLists.txt
        picoruby/
          build_config/
            xtensa-esp.rb      # mruby cross-compile configuration
          mrbgems/
            picoruby-ws2812/   # WS2812 LED driver
            picoruby-irq/      # Interrupt library
  components/        # Build directory (git-ignored)
    R2P2-ESP32/      # Cloned PicoRuby runtime
```
