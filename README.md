# Ruby WASM Sound Visualizer

A browser-based audio visualizer written in Ruby.

Analyzes microphone input in real-time and generates 3D visual effects using Three.js.

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

| Key | Function |
|------|------|
| `0` | Color Mode: Grayscale |
| `1` | Color Mode: Red spectrum (240-120°) |
| `2` | Color Mode: Green spectrum (0-240°) |
| `3` | Color Mode: Blue spectrum (120-360°) |
| `4` / `5` | Hue shift -5° / +5° |
| `6` / `7` | Max brightness -5 / +5 (0-255) |
| `8` / `9` | Max lightness -5 / +5 (0-255) |
| `-` / `+` | Sensitivity -0.05 / +0.05 |

Current settings and key guide are always displayed in the bottom-left corner of the screen.

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

### Visual Effects

- Particle System: Massive particles exploding in response to sound and frequency bands
- Beat Detection: Real-time beat detection for Bass, Mid, and High frequencies
- BPM Estimation: Automatic BPM (Beats Per Minute) calculation from detected beats
- Color Modes: Multiple color schemes (Grayscale, Red spectrum, Green spectrum, Blue spectrum) with manual hue shift
- Frequency-Based Colors: Dynamic colors based on frequency bands (Bass/Mid/High)
- Geometry Morphing: Torus (donut shape) scales and rotates with the music
- Glow Effects: Bloom effect makes the entire screen glow
- Camera Shake: Intense bass triggers camera shake for immersive experience

### Technology

- Ruby 3.4.7 (@ruby/4.0-wasm-wasi) - All logic implemented in Ruby
- Three.js - 3D rendering and post-processing
- Web Audio API - Microphone input and frequency analysis
- Single HTML File - Easy deployment

## File Structure

```
ruby_sound_visualizer/
├── README.md           # This file
├── CLAUDE.md           # Detailed documentation
├── Gemfile             # Ruby dependency management
├── .ruby-version       # Ruby version specification (3.4.7)
└── index.html          # Main application (contains all code)
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

You can edit code in the following sections of `index.html`:

- Ruby code: Inside `<script type="text/ruby" id="...">` blocks
  - `ruby-analyzer`: Audio analysis and beat detection
  - `ruby-particle-system`: Particle physics and explosion effects
  - `ruby-color-palette`: Color calculation and hue modes
  - `ruby-geometry-morpher`: Torus scaling and rotation
  - And more...
- JavaScript code: Inside `<script>` blocks at the bottom
  - Web Audio API setup
  - Three.js rendering
  - Keyboard event handlers

Important: After making changes, reload the browser. Ruby WASM initialization may take 25-30 seconds on first load.

### Debugging

- Open browser DevTools (F12) and check Console tab
- Ruby errors appear as `[Ruby] Error: ...`
- JavaScript errors appear normally in console
- Use `console.log` for debugging both Ruby and JavaScript code

## Future Enhancements

- God Rays: Crepuscular rays effect for dramatic lighting
- Preset System: Save and load custom visual configurations
- MIDI Controller: External hardware control support
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
