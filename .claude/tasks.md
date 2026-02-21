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
