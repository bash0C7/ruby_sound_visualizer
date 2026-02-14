# Ruby WASM Sound Visualizer - Project Tasks

Project task list for tracking progress.

## Completed

- [x] Perf View window frozen (particles do not move)
  - Root cause: Chrome throttles `requestAnimationFrame` to 1fps in background/popup windows
  - Fix: Use `setTimeout(animate, 16)` instead of `requestAnimationFrame` in perf view mode
  - Verified: `?perf=1` direct tab works at FPS 47; popup now uses timer-based loop

- [x] Web Serial -> ATOM Matrix LED meter + low/mid/high analyzer (PicoRuby firmware)
  - SerialProtocol: ASCII stateless frame format `<L:NNN,B:NNN,M:NNN,H:NNN>\n`
  - SerialManager: connection state, TX/RX buffer, baud rate management
  - Browser-side: Web Serial API JS glue (connect, disconnect, send, read loop)
  - PicoRuby firmware: `picoruby/led_visualizer.rb` for 5x5 WS2812 matrix
  - LED mapping: columns 0-1=Bass(red), 2=Mid(green), 3-4=High(blue)
  - Control panel: Serial button + baud select + Auto TX checkbox

- [x] WordArt text effect plugin (command input)
  - WordartRenderer: 4 style presets (rainbow_arc, gold_emboss, neon_glow, chrome_3d)
  - Animation phases: entrance (0.5s) -> sustain (3s, audio-reactive) -> exit (0.75s)
  - Entrance animations: zoom_spin, slide_bounce, typewriter, drop_in
  - Exit animations: fade_shrink, slide_out, glitch_out
  - VJ Pad commands: `wa "TEXT"`, `was` (stop)
  - Canvas overlay rendering via minimal JS

- [x] Web Serial API command input plugin (send/receive via serial)
  - VJ Pad DSL commands: sc, sd, ss, sr, st, sb, si, sa, scl
  - Serial RX display area next to VJ Prompt
  - Auto-send mode: transmit audio frame each visualizer update
  - Baud rate selection: 38400 / 115200

- [x] Pen input with fade-out (mouse drawing on screen)
  - PenInput: stroke collection, color sync with ColorPalette
  - Fade-out: 3 seconds linear opacity decay
  - Canvas overlay with pointer-events management
  - VJ Pad command: `pc` (clear strokes)
  - Colors synced with current hue mode for girly aesthetic

## Notes

- All tasks implemented with t-wada style TDD (115 new tests, 100% pass)
- Ruby-first implementation: all logic in Ruby, minimal JS for browser API glue
- Chrome MCP browser testing deferred to local sessions
