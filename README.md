# Ruby WASM Sound Visualizer

**マイクの音に反応して、ブラウザで超派手な 3D ビジュアルエフェクトを生成する音響ビジュアライザー（VJ ソフトウェア）**

A browser-based audio visualizer (VJ software) written in Ruby that generates stunning 3D visual effects responding to your microphone input.

## ✨ What You'll Experience

- **🎤 Real-time Audio Reaction**: Play music near your microphone and watch the visuals explode with energy
- **🌟 Massive Particle System**: 10,000 particles bursting and flowing with the beat
- **💎 Dynamic Geometry**: 3D torus morphing and rotating in sync with bass, mid, and treble
- **✨ Bloom Glow Effects**: Entire screen glows and pulses with the music intensity
- **🎭 VRM Avatar Dancing**: Load your VRM character and watch it dance to the beat with glowing effects
- **🎨 Multiple Color Modes**: Switch between grayscale, red spectrum, green spectrum, and blue spectrum
- **🎚️ Real-time Controls**: Adjust sensitivity, brightness, hue, and more with keyboard shortcuts
- **📊 Live Audio Analysis**: See BPM estimation and frequency breakdown (Bass/Mid/High) in real-time

**No installation required** - just open in your browser, allow microphone access, and start the party! 🎉

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

## 🎯 Key Features

### 🎨 Visual Effects You Can Experience

- **Particle Explosions**: 10,000 particles burst and flow in response to sound intensity and frequency
- **Morphing Geometry**: 3D torus (donut shape) scales and rotates with bass, mid, and treble frequencies
- **Bloom Glow**: Screen glows and pulses with music energy - from subtle shimmer to intense white-hot brightness
- **VRM Avatar Integration**: Load your own VRM character model and watch it dance and glow with the music
- **Beat-Reactive Motion**: Real-time beat detection triggers dynamic movements and visual bursts
- **Color Spectrum Modes**: Switch between 4 color schemes - grayscale, red, green, or blue spectrum palettes
- **Camera Effects**: Intense bass triggers camera shake for immersive experience

### 🎚️ Real-time Controls

- **Audio Sensitivity**: Adjust how strongly visuals react to sound (`-` / `+` keys)
- **Color Mode Switching**: Change color palettes on the fly (`0`-`3` keys)
- **Hue Shifting**: Fine-tune colors with manual hue rotation (`4` / `5` keys)
- **Brightness Controls**: Adjust max brightness and lightness (`6`-`9` keys)
- **Live Monitoring**: See current BPM, frequency levels, and settings on-screen

### 🛠️ Technology Stack

- **Ruby 3.4.7** (@ruby/4.0-wasm-wasi) - All audio analysis and visual logic written in Ruby, running in browser via WebAssembly
- **Three.js** - High-performance 3D rendering with post-processing effects
- **Web Audio API** - Real-time microphone input and frequency analysis
- **VRM Support** - 3D avatar character integration (@pixiv/three-vrm)
- **Zero Backend** - Fully client-side, no server required after initial load

## 📁 File Structure

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

**Ruby Logic** - Edit files in `src/ruby/`:
- `audio_analyzer.rb` - Frequency analysis algorithms and beat detection logic
- `particle_system.rb` - Particle physics, explosion effects, and boundary conditions
- `color_palette.rb` - Color mode calculations and HSV conversion
- `geometry_morpher.rb` - Torus scaling and rotation parameters
- `bloom_controller.rb` - Bloom glow strength and threshold settings
- `vrm_material_controller.rb` - VRM character glow intensity (adjust `DEFAULT_BASE_EMISSIVE_INTENSITY` and `MAX_EMISSIVE_INTENSITY` here)
- Other .rb files for additional effects

**JavaScript/HTML** - Edit `index.html`:
- Web Audio API setup and microphone handling
- Three.js scene configuration and rendering
- Keyboard event handlers and UI updates
- VRM loader and material setup

**Important**: After making changes, **hard refresh** your browser (Ctrl+Shift+R / Cmd+Shift+R) to clear cached .rb files. Ruby WASM initialization takes 25-30 seconds on first load.

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
