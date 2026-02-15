# Serial Audio Protocol: PicoRuby to Chrome

## Overview

This document defines the serial protocol for sending PWM frequency data
from PicoRuby devices to the Chrome-based Ruby Sound Visualizer.
The Chrome side receives frequency/duty data and generates audio output
via Web Audio API PWM oscillator.

## Direction

```
PicoRuby (ESP32) --USB Serial--> Chrome (ruby.wasm + Web Audio API)
```

This is the reverse direction of the existing audio level protocol:
```
Chrome --USB Serial--> PicoRuby (existing: <L:NNN,B:NNN,M:NNN,H:NNN>)
```

Both directions share the same serial connection and frame format conventions.

## Frame Format

```
<F:NNNNN,D:NNN>\n
```

- Start marker: `<`
- End marker: `>`
- Terminator: `\n` (newline)
- Fields:
  - `F`: Frequency in Hz (integer, 0-20000)
  - `D`: Duty cycle percentage (integer, 0-100)

## Examples

```
<F:440,D:50>\n      # A4 note, 50% duty (standard square wave)
<F:880,D:50>\n      # A5 note, 50% duty
<F:262,D:25>\n      # C4 note, 25% duty (narrower pulse)
<F:0,D:0>\n         # Silence (0 Hz)
<F:1000,D:75>\n     # 1kHz tone, 75% duty
```

## Value Ranges

| Field | Min | Max | Unit | Notes |
|-------|-----|-----|------|-------|
| F     | 0   | 20000 | Hz | 0 = silence, audible range 20-20000 |
| D     | 0   | 100   | %  | 50 = square wave, controls timbre |

## Duty Cycle Effect on Timbre

- `D:50` - Standard square wave (only odd harmonics)
- `D:25` or `D:75` - Brighter sound (more harmonics)
- `D:10` or `D:90` - Very bright/nasal sound (pulse wave)
- `D:0` or `D:100` - Silence (DC offset only)

## Chrome Side Behavior

1. Chrome receives frames via existing Web Serial read loop
2. SerialProtocol.decode_frequency() parses the frame
3. SerialAudioSource updates frequency/duty state
4. Web Audio API OscillatorNode generates PWM waveform
5. Audio routes to both:
   - AnalyserNode (for visualization)
   - AudioContext.destination (for speaker output)

## Coexistence with Existing Protocol

Both frame types can be sent on the same serial connection:
- Audio level frames: `<L:NNN,B:NNN,M:NNN,H:NNN>\n` (Chrome to PicoRuby)
- Frequency frames: `<F:NNNNN,D:NNN>\n` (PicoRuby to Chrome)

The parser distinguishes them by field prefix (L/B/M/H vs F/D).

## PicoRuby Implementation

The PicoRuby side needs to:
1. Format frequency data as `<F:NNNNN,D:NNN>\n`
2. Send via UART at the configured baud rate (default: 115200)

Minimal sending code:
```ruby
def send_frequency_frame(uart, freq, duty)
  frame = "<F:#{freq.to_i},D:#{duty.to_i}>\n"
  uart.write(frame)
end
```

---

## Prompt for PicoRuby Side Implementation

Use this prompt to generate the PicoRuby serial sending code:

```
# PicoRuby Serial Audio Frequency Sender

Add serial frequency frame sending to the existing PicoRuby code.

## Protocol
Send frequency/duty data to Chrome using this ASCII frame format:
<F:NNNNN,D:NNN>\n

- F: frequency in Hz (integer, 0-20000)
- D: duty cycle percentage (integer, 0-100)
- Frame starts with '<', ends with '>\n'

## Implementation Requirements

1. Use the existing UART connection (ESP32_UART0, 115200 baud)
2. Send frequency frames at a reasonable rate (e.g., every 50-100ms)
3. Format: "<F:#{current_freq},D:#{current_duty}>\n"
4. The Chrome side already handles receiving and parsing these frames

## Reference: Existing otpwm.rb Pattern

The current code calculates frequency from distance sensor:
```ruby
distance_ratio = (@distance - DIST_VALID_MIN).to_f / @dist_range
@current_freq = (FREQ_MIN * (@freq_ratio ** distance_ratio)).to_i
```

Add after the frequency calculation:
```ruby
send_frequency_frame(uart, @current_freq, @current_duty)
```

Where send_frequency_frame is:
```ruby
def send_frequency_frame(uart, freq, duty)
  frame = "<F:#{freq.to_i},D:#{duty.to_i}>\n"
  uart.write(frame)
end
```

## Coexistence
This protocol coexists with the existing audio level protocol
(<L:NNN,B:NNN,M:NNN,H:NNN>) on the same serial connection.
Chrome distinguishes frame types by field prefix.
```
