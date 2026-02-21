# Ruby WASM Sound Visualizer - Project Tasks

Project task list for tracking progress.

## Notes

- All tasks implemented with t-wada style TDD (800 tests, 100% pass)
- Ruby-first implementation: all logic in Ruby, minimal JS for browser API glue
- Chrome MCP browser testing deferred to local sessions
- Global variables eliminated: VisualizerApp container class replaces 15 `$` globals


## PicoRuby LED Visualizer Tasks (ATOM Matrix)

### DONE items (this session)

- [P-1] DONE: Add `require 'uart'` to led_visualizer.rb (was causing NameError on boot)
- [P-2] DONE: Fix `byte.length == 1` validation in serial receive loop (following otma.rb pattern)
- [P-3] DONE: Fix WS2812 `show_hsb_hex` API usage — rewritten to packed HSB integer format
  - `pack_hsb(hue, sat, bri)` helper + `led.show_hsb_hex(*colors)` splat call
  - Old code passed 4 args treated as 4 LED colors (SATURATION=255 → white LED)
- [P-4] DONE: Add complementary color fill to LED matrix
  - Signal rows: main color (red/green/blue) by VU level
  - Unlit rows: complementary color (cyan/magenta/yellow) at dim brightness
  - `COMPLEMENT_MAX=45`, `COMPLEMENT_MIN=5` (always-on floor in silence)
- [P-5] DONE: Update rake-picoruby skill with serial port disconnect + `$>` crash detection
- [P-6] DONE: Update picoruby/CLAUDE.md with `rake build flash monitor` task chaining

### Pending

- [P-7] PENDING: Hardware verification of complementary color + silence floor
  - Need `rake build flash` then reconnect Chrome Web Serial + enable Auto TX
  - Verify: silence → faint complement glow; loud audio → vivid RGB VU meter
- [P-8] PENDING: Visual parameter tuning based on hardware feedback
  - `COMPLEMENT_MAX=45` (complement max brightness) — adjust if too dim/bright
  - `COMPLEMENT_MIN=5` (silence floor) — adjust if invisible or too strong
  - If complement looks washed out, try reducing SATURATION for complement rows
- [P-9] PENDING: Consider adding ambient complement animation (optional/future)
  - Currently complement brightness is static in silence (fixed at COMPLEMENT_MIN)
  - Could add slow sine-wave pulse for ambient glow when no audio detected

- [P-10] PENDING [Web/Local]: Add button UART send to led_visualizer.rb
  - File: picoruby/src_components/R2P2-ESP32/storage/home/led_visualizer.rb
  - Step 1: Add at top of file (after existing requires):
      require 'gpio'
      require 'irq'
  - Step 2: After `led = WS2812.new(RMTDriver.new(LED_PIN))` line, add:
      button = GPIO.new(39, GPIO::IN|GPIO::PULL_UP)
      irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {uart: uart}) do |btn, ev, cap|
        cap[:uart].write("<F:440,D:50>\n")
      end
  - Step 3: First line inside `while true` loop, add:
      IRQ.process
  - Step 4: After `end` of `while true` block, add:
      irq.unregister
  - Pattern ref: otpwm.rb lines 273, 290-293 (in ~/src/Arduino/picoruby-ot — read-only ref OK)
  - PicoRuby compat: no inline rescue, no defined?, no lambda/proc (see picoruby/CLAUDE.md)

- [P-11] PENDING [Web/Local]: Hardware verify — button triggers Chrome 440Hz audio
  - APP=led_visualizer rake build flash, reconnect Chrome Web Serial + enable Auto TX
  - Press GPIO39 button → SerialRxDisplay shows `<F:440,D:50>` → Chrome plays 440Hz tone
  - Use /rake-picoruby skill for build/flash/monitor operations

- [P-12] PENDING [Web/Local]: Button behavior tuning (optional/future)
  - Current: fixed 440Hz per press
  - Alternatives: toggle mute, level-derived frequency, hold-to-sustain

## Documentation Update Tasks [Web/Local]

- [D-1] PENDING [Web/Local]: Fix WS2812 Reference in picoruby/CLAUDE.md
  - File: picoruby/CLAUDE.md — section "### WS2812 Reference"
  - Replace the entire WS2812 Reference code block:
    WRONG (current):
      led.show_hsb_hex(index, hue, saturation, brightness)
      led.show  # flush to hardware
    CORRECT (replace with):
      # Pack HSB into single integer: (hue << 16) | (saturation << 8) | brightness
      def pack_hsb(hue, saturation, brightness)
        (hue << 16) | (saturation << 8) | brightness
      end

      colors = []
      25.times { colors << pack_hsb(hue, 255, brightness) }
      led.show_hsb_hex(*colors)  # splat packed integer array; no led.show needed
  - Confirmed correct API from led_visualizer.rb lines 94-96 and 120

## picoruby-ot Tasks [LOCAL ONLY]

NOTE: ~/src/Arduino/picoruby-ot は Claude Code on the Web からアクセス不可。
      ローカル Claude Code セッションでのみ実施すること。

- [OT-1] PENDING [LOCAL]: Create otv.rb in picoruby-ot project
  - New file: /Users/bash/src/Arduino/picoruby-ot/src_components/R2P2-ESP32/storage/home/otv.rb
  - Base: otpwm.rb をコピーして以下を変更
  - REMOVE from otpwm.rb:
    - `require 'pwm'`
    - `DEBUG = true` / `NOISE_MODE = false` フラグ
    - DPWM クラス（デバッグ用 PWM）
    - NoisyPWM クラス（ノイズ変動 PWM）
    - SimplePWM クラス
    - `speaker = if NOISE_MODE ... end` の初期化ブロック
  - ADD new class UARTSender (after Speaker module, before NoiseInstrument):
      require 'uart'

      BAUD_RATE = 115_200

      class UARTSender
        include Speaker

        def initialize(uart, param = {})
          initialize_speaker(muted: param[:muted] == false ? false : true)
          @uart = uart
          @last_freq = 0
          @last_duty = 50
        end

        protected

        def set_frequency(f)
          @last_freq = f
          @uart.write("<F:#{f},D:#{@last_duty}>\n")
        end

        def set_duty(d)
          @last_duty = d
          @uart.write("<F:#{@last_freq},D:#{d}>\n")
        end
      end
  - REPLACE main initialization block:
      uart = UART.new(unit: :ESP32_UART0, baudrate: BAUD_RATE)
      sender = UARTSender.new(uart)
      # (button, led_strip, i2c_bus, accel_sensor, tof_sensor — same as otpwm.rb)
      instrument = NoiseInstrument.new(sender, tof_sensor)
      led_viz = AmbientLEDVisualizer.new(led_strip)
      irq = button.irq(GPIO::EDGE_FALL, debounce: 100, capture: {viz: led_viz, spk: sender}) do |btn, ev, cap|
        cap[:spk].toggle_mute
        cap[:viz].flash
      end
  - KEEP unchanged: Speaker module, SimpleRandom class, NoiseInstrument class,
                    AmbientLEDVisualizer class, main loop, irq.unregister
  - Note: toggle_mute OFF → Speaker#set_duty(0) → UARTSender#set_duty → writes <F:0,D:0>
  - PicoRuby compat: no inline rescue, no defined?, no lambda/proc
  - Build verify: cd ~/src/Arduino/picoruby-ot && APP=otv rake build

- [OT-2] PENDING [LOCAL]: Update picoruby-ot README.md
  - File: /Users/bash/src/Arduino/picoruby-ot/README.md
  - Add to Overview section (after otpwm.rb description):
      ### otv.rb - Distance Sensor UART Visualizer
      - Distance-to-frequency mapping (20mm-300mm -> 200Hz-1000Hz, same as otpwm.rb)
      - UART output instead of PWM: sends <F:NNNNN,D:NNN> frames to Chrome via USB Serial
      - WS2812 LED strip visualization (same as otpwm.rb)
      - Use with ruby_sound_visualizer for Chrome Web Audio API PWM tone playback
      - Button toggles mute (UART send on/off)
  - Add to File Structure under storage/home/:
      │   └── otv.rb               # Distance sensor UART visualizer (for Chrome audio)
  - Add to Usage section:
      ### otv.rb (UART Visualizer for Chrome)
      1. Flash `otv.rb` to ATOM Matrix
      2. Connect sensors via J3 (I2C: GPIO25=SDA, GPIO21=SCL) — same as otpwm.rb
      3. Connect USB to Mac running Chrome
      4. Open ruby_sound_visualizer, connect Web Serial
      5. Move hand near ToF sensor — Chrome plays PWM tone via Web Audio API
      6. Press button to mute/unmute UART frequency output
  - Add to Architecture section:
      └── otv.rb
          ├── NoiseInstrument: Distance -> frequency/duty mapping (reused from otpwm.rb)
          ├── AmbientLEDVisualizer: LED visualization (reused from otpwm.rb)
          ├── UARTSender: UART <F:NNN,D:NNN> frame output (replaces PWM)
          └── WS2812 LED Strip (GPIO26)

## Implementation Order

| Step | Task | Environment |
|------|------|-------------|
| 1 | [D-1] Fix WS2812 Reference in picoruby/CLAUDE.md | Web/Local |
| 2 | [P-10] Add button UART send to led_visualizer.rb | Web/Local |
| 3 | Commit D-1 + P-10 via git subagent | Web/Local |
| 4 | [P-11] Hardware verify (manual, human-operated) | Web/Local |
| 5 | [OT-1] Create otv.rb | LOCAL ONLY |
| 6 | [OT-2] Update picoruby-ot/README.md | LOCAL ONLY |
| 7 | Commit OT-1 + OT-2 in picoruby-ot repo (local git) | LOCAL ONLY |
