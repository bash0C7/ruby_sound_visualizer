# PicoRuby Theremin Instrument (otv.rb)

## Overview

`otv.rb` is a PicoRuby firmware that implements a theremin-like musical instrument.
A VL53L0X time-of-flight distance sensor maps hand position to frequency,
which is sent via UART to the Chrome ruby.wasm synthesizer for audio output and visualization.

## Signal Flow

```
Hand position
  ↓
VL53L0X ToF sensor (I2C) → distance in mm
  ↓ NoiseInstrument#update
Distance → Frequency (logarithmic scale: FREQ_MIN=200Hz to FREQ_MAX=1000Hz)
Distance → Duty cycle (BASE_DUTY=40%)
  ↓ UARTSender
<F:NNNNN,D:NNN>\n frame via UART (115200 baud)
  ↓ USB Serial / Web Serial API
Chrome ruby.wasm SerialAudioSource
  ↓
SynthEngine → OscillatorNode → AudioContext
  ↓
Audio output + visualization
```

The WS2812 LED strip provides local visual feedback simultaneously.

## Hardware

- **MCU**: ESP32 (R2P2-ESP32 board, not ATOM Matrix)
- **Distance sensor**: VL53L0X (I2C, SDA=GPIO25, SCL=GPIO21)
- **LED strip**: 29x WS2812 (GPIO 26)
- **Button**: GPIO 39 (active low, IRQ-driven mute toggle)
- **UART**: ESP32_UART0 (115200 baud, same USB cable as Chrome Web Serial)

## Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| DIST_VALID_MIN | 20mm | Minimum valid sensor range |
| DIST_VALID_MAX | 300mm | Maximum valid sensor range |
| FREQ_MIN | 200Hz | Frequency at max distance |
| FREQ_MAX | 1000Hz | Frequency at min distance |
| BASE_DUTY | 40% | Normal duty cycle |
| DISTANCE_SMOOTH_ALPHA | 50 | EMA smoothing factor (integer, 0-100) |
| BAUD_RATE | 115200 | UART baud rate |

## Frequency Mapping

Frequency uses logarithmic scale for perceptual octave feel:

```
freq = FREQ_MIN * (FREQ_MAX / FREQ_MIN) ^ ((distance - DIST_VALID_MIN) / dist_range)
```

- Closer hand → higher frequency
- Out-of-range or invalid sensor readings trigger fade-out (FADE_RATE=0.2 per frame)
- Distance is smoothed with EMA (Exponential Moving Average) to reduce noise jitter

## LED Visualization

29-LED WS2812 strip driven by `AmbientLEDVisualizer` (GPIO 26):

- Wave offset controlled by distance only — stationary hand = fixed pattern
- 4 color bands mapped to distance range:
  - 20-80mm → red (hue 0-96)
  - 80-160mm → cyan (hue 96-192)
  - 160-240mm → magenta (hue 192-288)
  - 240-300mm → yellow (hue 288-384)
- Brightness proportional to duty cycle value (1-60 → 10-100)
- Button press triggers flash effect and toggles UART mute

## Key Classes

| Class | Responsibility |
|-------|----------------|
| `NoiseInstrument` | Distance reading, EMA smoothing, frequency/duty calculation |
| `UARTSender` | Formats and sends `<F:NNNNN,D:NNN>` frames via UART |
| `Speaker` (module) | Mute state management, included by UARTSender |
| `AmbientLEDVisualizer` | Controls 29-LED WS2812 strip with distance-mapped colors |

## Build and Flash

```bash
cd picoruby && APP=otv rake build flash monitor
```

## Source File

`picoruby/src_components/R2P2-ESP32/storage/home/otv.rb` — edit here (git-tracked).

## Serial Protocol

See `picoruby/SERIAL_AUDIO_PROTOCOL.md` for the full `<F:NNNNN,D:NNN>` frame specification.

On the Chrome side:
- `SerialProtocol.decode_frequency()` parses incoming frames
- `SerialAudioSource` tracks frequency/duty state
- `SynthEngine` drives `OscillatorNode` for audio output

## Main Loop Structure

```ruby
loop do
  IRQ.process                          # Handle button events (mute toggle, LED flash)

  instrument.update                    # Read sensor, compute frequency/duty, send UART frame

  if loop_counter % 4 == 0            # Update LEDs every 4 frames
    led_viz.update(freq, duty, dist)
    led_viz.show
  end

  loop_counter += 1
end
```
