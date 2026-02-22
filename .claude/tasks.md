# Ruby WASM Sound Visualizer - Project Tasks

Project task list for tracking progress.

## Notes

- All tasks implemented with t-wada style TDD (800 tests, 100% pass)
- Ruby-first implementation: all logic in Ruby, minimal JS for browser API glue
- Chrome MCP browser testing deferred to local sessions
- Global variables eliminated: VisualizerApp container class replaces 15 `$` globals


## PicoRuby LED Visualizer Tasks (ATOM Matrix)

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

- [P-11] PENDING [Web/Local]: Hardware verify — button triggers Chrome 440Hz audio
  - APP=led_visualizer rake build flash, reconnect Chrome Web Serial + enable Auto TX
  - Press GPIO39 button → SerialRxDisplay shows `<F:440,D:50>` → Chrome plays 440Hz tone
  - Use /rake-picoruby skill for build/flash/monitor operations

- [P-12] PENDING [Web/Local]: Button behavior tuning (optional/future)
  - Current: fixed 440Hz per press
  - Alternatives: toggle mute, level-derived frequency, hold-to-sustain

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
