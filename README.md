# Ruby WASM Sound Visualizer

A browser-based audio visualizer written in Ruby that responds to microphone input in real time. The application runs entirely in the browser via WebAssembly.

## Quick Start

### 1. Setup

```bash
# Install dependencies
bundle install
```

### 2. Start Server

```bash
# Start Ruby WEBrick server
bundle exec ruby -run -ehttpd . -p8000
```

### 3. Open in Browser

```
http://localhost:8000/index.html
```

### 4. Allow Microphone Access

When the browser prompts for microphone permission, click "Allow"

### 5. Play Music

Play music near your speakers or microphone, and the visualizer will automatically react!

## Keyboard Controls

You can adjust parameters in real-time using keyboard shortcuts.

### Interface Controls

| Key | Function |
|------|------|
| `` ` `` | Toggle VJ Pad command interface (backtick) |
| `p` | Toggle Controls panel |
| `m` | Toggle microphone on/off |
| `Alt+V` | Load/unload VRM avatar model |
| `Alt+T` | Toggle tab audio capture |
| `Alt+C` | Toggle camera video capture |
| `d` / `f` | Rotate camera left / right |
| `e` / `c` | Rotate camera up / down |

### Parameter Adjustment

| Key | Function |
|------|------|
| `0` | Color Mode: Grayscale |
| `1` | Color Mode: Vivid Red (centered at 0°, ±70° range) |
| `2` | Color Mode: Shocking Yellow (centered at 60°, ±70° range) |
| `3` | Color Mode: Turquoise Blue (centered at 180°, ±70° range) |
| `4` / `5` | Hue shift -5° / +5° |
| `6` / `7` | Max brightness -5 / +5 (0-255) |
| `8` / `9` | Max lightness -5 / +5 (0-255) |
| `-` / `+` | Sensitivity -0.05 / +0.05 |

Current settings and key guide are always displayed in the bottom-left corner of the screen.

## VJ Pad (Real-time Command Interface)

Press the backtick key (`) to open the VJ Pad prompt at the bottom of the screen. Type commands and press Enter to execute them. The VJ Pad allows real-time control of all visualizer parameters through a Ruby DSL.

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `c <mode>` | Set color mode (0=Gray, 1=Red, 2=Green, 3=Blue) | `c 1` |
| `h <degrees>` | Set hue offset (0-360) | `h 180` |
| `s <value>` | Set sensitivity | `s 1.5` |
| `br <value>` | Set max brightness (0-255) | `br 200` |
| `lt <value>` | Set max lightness (0-255) | `lt 180` |
| `em <value>` | Set emissive intensity | `em 0.5` |
| `bm <value>` | Set bloom strength | `bm 3.0` |
| `burst [force]` | Trigger particle burst effect (plugin) | `burst 2.0` |
| `flash [intensity]` | Trigger bloom flash effect (plugin) | `flash 1.5` |
| `shockwave [force]` | Bass-heavy impulse with bloom flash (plugin) | `shockwave 2.0` |
| `strobe [intensity]` | Quick bloom strobe flash (plugin) | `strobe 3.0` |
| `rave [level]` | Max energy preset with param boost (plugin) | `rave 1.5` |
| `wa "text"` | Display 90s WordArt text with animation | `wa "HELLO"` |
| `was` | Stop current WordArt animation | `was` |
| `sc` | Connect to serial device (Web Serial) | `sc` |
| `sd` | Disconnect serial device | `sd` |
| `ss "text"` | Send text over serial | `ss "hello"` |
| `sr [n]` | Show last n lines of serial receive log | `sr 10` |
| `si` | Show serial connection status | `si` |
| `sa 1/0` | Enable/disable auto-send of audio frames | `sa 1` |
| `pc` | Clear pen drawing strokes | `pc` |
| `plugins` | List all available plugin commands | `plugins` |
| `r` | Reset all parameters to defaults | `r` |

### Command Features

- Multiple commands: Separate commands with semicolons to execute sequentially
  - Example: `c 1; s 2.0; flash`
- Getters: Type command name without arguments to get current value
  - Example: `s` returns current sensitivity
- Symbol aliases: Color mode supports symbols (`:red`, `:r`, `:green`, `:g`, `:blue`, `:b`, `:gray`)
  - Example: `c :red` is equivalent to `c 1`
- History navigation: Use Up/Down arrow keys to navigate command history
- Error feedback: Errors are displayed in red text in the prompt

### Command Examples

```
c 3              # Switch to blue mode
s 2.0            # Double sensitivity
c 1; burst       # Switch to red and trigger burst
h 90; flash      # Shift hue 90 degrees and flash
c :blue; s 1.5   # Blue mode with 1.5x sensitivity
```

Press backtick (`) again or Escape to close the prompt.

### Plugin System

Effect commands are implemented as plugins. Built-in plugins include burst, flash, shockwave, strobe, and rave. Each plugin is a standalone Ruby file in `src/ruby/plugins/` that defines a VJ Pad command and its visual effects.

To add a custom effect, create a plugin file:

```ruby
# src/ruby/plugins/vj_nova.rb
VJPlugin.define(:nova) do
  desc "Combined impulse and bloom nova"
  param :force, default: 1.0, range: 0.0..3.0
  param :glow, default: 2.0, range: 0.0..5.0

  on_trigger do |params|
    f = params[:force]
    g = params[:glow]
    {
      impulse: { bass: f, mid: f, high: f, overall: f },
      bloom_flash: g
    }
  end
end
```

Then add a script tag in `index.html` to load it. The command becomes available in VJ Pad immediately. See CLAUDE.md for the full plugin development guide.

## URL Parameters

You can specify initial values using URL query parameters.

```
http://localhost:8000/index.html?sensitivity=1.5&maxBrightness=200&maxLightness=180
```

| Parameter | Description | Default | Range |
|-------------|------|-----------|------|
| `sensitivity` | Audio sensitivity (multiplier) | `1.0` | 0.1~ |
| `maxBrightness` | Max brightness (particle color output limit) | `255` | 0-255 |
| `maxLightness` | Max lightness (HSV V value limit) | `255` | 0-255 |

## Features

The visualizer includes:

- 3,000 particles that respond to sound intensity and frequency
- 3D torus that scales and rotates based on bass, mid, and treble frequencies
- Bloom glow effect that increases in brightness with audio intensity
- VRM avatar support for loading and animating 3D character models
- Beat detection for timing visual effects
- Four color modes: grayscale, red spectrum, green spectrum, and blue spectrum
- Camera shake triggered by bass frequencies
- Real-time parameter adjustment via keyboard shortcuts
- VJ Pad command interface for advanced real-time control via Ruby DSL
- Plugin system for adding custom VJ Pad effect commands
- Live display of BPM and frequency levels
- 90s WordArt text animation with 4 style presets and PowerPoint-style entrance/exit effects
- Web Serial integration for sending audio data to external hardware (ATOM Matrix LED)
- Pen input overlay for mouse drawing with fade-out, colors synced with particle palette
- Performance view mode for multi-monitor setups

## Technology

- Ruby 3.4.7 (@ruby/4.0-wasm-wasi) for audio analysis and visual logic
- Three.js for 3D rendering
- Web Audio API for microphone input and frequency analysis
- Web Serial API for hardware device communication
- VRM support via @pixiv/three-vrm
- Fully client-side, no backend required

## File Structure

```
ruby_sound_visualizer/
├── index.html                    # Main HTML file (loads all components)
├── src/ruby/                     # Ruby logic (loaded via ruby.wasm)
│   ├── plugins/                  # VJ Pad plugin commands
│   │   ├── vj_burst.rb           #   Burst effect (impulse injection)
│   │   ├── vj_flash.rb           #   Flash effect (bloom flash)
│   │   ├── vj_shockwave.rb       #   Shockwave effect (bass impulse + bloom)
│   │   ├── vj_strobe.rb          #   Strobe effect (quick bloom flash)
│   │   ├── vj_rave.rb            #   Rave preset (max energy + param boost)
│   │   ├── vj_serial.rb          #   Web Serial plugin (connect/send/receive)
│   │   └── vj_wordart.rb         #   WordArt text effect plugin
│   ├── vj_plugin.rb              # Plugin system core (registry and DSL)
│   ├── effect_dispatcher.rb      # Plugin effects to EffectManager translator
│   ├── vj_pad.rb                 # VJ Pad command interface (delegates to plugins)
│   ├── effect_manager.rb         # Coordinates all visual effects
│   ├── audio_analyzer.rb         # Frequency analysis and beat detection
│   ├── particle_system.rb        # Particle physics and explosions
│   ├── serial_protocol.rb        # ASCII serial frame format (encode/decode)
│   ├── serial_manager.rb         # Serial connection state machine
│   ├── wordart_renderer.rb       # 90s WordArt text animation engine
│   ├── pen_input.rb              # Mouse pen drawing with fade-out
│   ├── geometry_morpher.rb       # Torus scaling and rotation
│   ├── bloom_controller.rb       # Bloom glow effect parameters
│   ├── camera_controller.rb      # Camera shake and positioning
│   ├── js_bridge.rb              # JavaScript-Ruby bridge layer
│   ├── main.rb                   # Entry point and main loop
│   └── ...                       # Other core modules
├── picoruby/                     # PicoRuby firmware for ATOM Matrix
│   ├── led_visualizer.rb         #   5x5 WS2812 LED VU meter firmware
│   └── CLAUDE.md                 #   PicoRuby project instructions
├── test/                         # Unit and integration tests
│   ├── test_vj_plugin.rb         # Plugin system tests
│   ├── test_effect_dispatcher.rb # Effect dispatcher tests
│   ├── test_vj_pad.rb            # VJ Pad tests (including plugin delegation)
│   ├── test_serial_protocol.rb   # Serial protocol tests
│   ├── test_serial_manager.rb    # Serial manager tests
│   ├── test_wordart_renderer.rb  # WordArt renderer tests
│   ├── test_pen_input.rb         # Pen input tests
│   ├── test_vj_pad_serial.rb     # VJ Pad serial command tests
│   └── ...                       # Other test files
├── README.md                     # This file (user guide)
├── CLAUDE.md                     # Detailed technical documentation
├── Gemfile                       # Ruby dependency management
├── .ruby-version                 # Ruby version (3.4.7)
└── .nojekyll                     # GitHub Pages: disable Jekyll processing
```

## Troubleshooting

### Microphone Not Working

- Protocol: Must run on HTTPS or localhost (security requirement)
- Permissions: Check browser microphone permission settings (usually in address bar icon)
- Audio Context: If no sound is detected, try clicking anywhere on the page to resume audio context
- Device: Ensure your microphone is connected and set as the default input device

### Low Performance

- Browser Tabs: Close unnecessary tabs to free up GPU memory
- Hardware Acceleration: Enable in browser settings (Chrome: Settings → System → Use hardware acceleration)
- DevTools: Close browser DevTools console when not debugging
- Display: Lower screen resolution or zoom level if needed

### Visual Issues

- Colors Not Changing: Press `0`, `1`, `2`, or `3` to cycle through color modes
- Too Bright/Dark: Use `6`/`7` (brightness) or `8`/`9` (lightness) keys to adjust
- Not Sensitive Enough: Press `+` to increase sensitivity, `-` to decrease

### Other Issues

See the "Troubleshooting" section in [CLAUDE.md](CLAUDE.md) for detailed technical documentation

## Development

### Local Development

```bash
# Install dependencies
bundle install

# Start WEBrick server
bundle exec ruby -run -ehttpd . -p8000

# Open in browser
open http://localhost:8000/index.html
```

### Code Modification

Ruby Logic - Edit files in `src/ruby/`:
- `audio_analyzer.rb` - Frequency analysis algorithms and beat detection logic
- `particle_system.rb` - Particle physics, explosion effects, and boundary conditions
- `color_palette.rb` - Color mode calculations and HSV conversion
- `geometry_morpher.rb` - Torus scaling and rotation parameters
- `bloom_controller.rb` - Bloom glow strength and threshold settings
- `visualizer_policy.rb` - Global configuration, brightness/lightness caps, and runtime settings
- `keyboard_handler.rb` - Keyboard shortcuts and input handling
- `bpm_estimator.rb` - BPM estimation algorithm and beat interval tracking
- `vrm_material_controller.rb` - VRM character glow intensity control
- Other .rb files for additional effects and utilities

JavaScript/HTML - Edit `index.html`:
- Web Audio API setup and microphone handling
- Three.js scene configuration and rendering
- Keyboard event handlers and UI updates
- VRM loader and material setup

After making changes, hard refresh your browser (Ctrl+Shift+R / Cmd+Shift+R) to clear cached .rb files.

### Debugging

- Open browser DevTools (F12) and check Console tab
- Ruby errors appear as `[Ruby] Error: ...`
- JavaScript errors appear normally in console
- Use `console.log` for debugging both Ruby and JavaScript code

## Future Enhancements

- God Rays: Crepuscular rays effect for dramatic lighting
- Preset System: Save and load custom visual configurations
- MIDI Controller: External MIDI hardware control support
- WebVR/WebXR: Virtual reality headset support
- Recording: Export visualizations as video files
- Audio File Input: Visualize uploaded audio files in addition to microphone

See "Future Enhancement Points" in [CLAUDE.md](CLAUDE.md) for details

## License

MIT License

## Links

- [Ruby WASM Documentation](https://ruby.github.io/ruby.wasm/)
- [Three.js](https://threejs.org/)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
