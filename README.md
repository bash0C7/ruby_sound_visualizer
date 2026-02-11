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

The visualizer includes:

- 10,000 particles that respond to sound intensity and frequency
- 3D torus that scales and rotates based on bass, mid, and treble frequencies
- Bloom glow effect that increases in brightness with audio intensity
- VRM avatar support for loading and animating 3D character models
- Beat detection for timing visual effects
- Four color modes: grayscale, red spectrum, green spectrum, and blue spectrum
- Camera shake triggered by bass frequencies
- Real-time parameter adjustment via keyboard shortcuts
- Live display of BPM and frequency levels

## Technology

- Ruby 3.4.7 (@ruby/4.0-wasm-wasi) for audio analysis and visual logic
- Three.js for 3D rendering
- Web Audio API for microphone input and frequency analysis
- VRM support via @pixiv/three-vrm
- Fully client-side, no backend required

## File Structure

```
ruby_sound_visualizer/
├── index.html                    # Main HTML file (loads all components)
├── src/ruby/                     # Ruby logic (loaded via ruby.wasm)
│   ├── audio_analyzer.rb         # Frequency analysis and beat detection
│   ├── particle_system.rb        # Particle physics and explosions
│   ├── geometry_morpher.rb       # Torus scaling and rotation
│   ├── color_palette.rb          # Color modes and HSV conversion
│   ├── bloom_controller.rb       # Bloom glow effect parameters
│   ├── camera_controller.rb      # Camera shake and positioning
│   ├── vrm_dancer.rb             # VRM character animation
│   ├── vrm_material_controller.rb # VRM glow intensity control
│   ├── effect_manager.rb         # Coordinates all visual effects
│   └── main.rb                   # Entry point and main loop
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
- `vrm_material_controller.rb` - VRM character glow intensity (adjust `DEFAULT_BASE_EMISSIVE_INTENSITY` and `MAX_EMISSIVE_INTENSITY` here)
- Other .rb files for additional effects

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
