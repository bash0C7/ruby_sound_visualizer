# Ruby WASM Sound Visualizer

🎵✨ A browser-based audio visualizer (VJ software) written in Ruby

Analyzes microphone input in real-time and generates stunning 3D visual effects using Three.js.

![Features](https://img.shields.io/badge/Particles-10k-blue) ![Effects](https://img.shields.io/badge/Effects-Bloom%2FParticles%2FGeometry-green) ![Language](https://img.shields.io/badge/Language-Ruby%2FJavaScript-red)

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

## Features

### Visual Effects

- **Particle System**: 10,000 particles exploding in response to sound
- **Frequency-Based Colors**: Bass (red) / Mid (green) / High (blue) colors change dynamically
- **Geometry Morphing**: Torus (donut shape) scales and rotates with the music
- **Glow Effects**: Bloom effect makes the entire screen glow

### Technology

- **Ruby 3.4.7** (@ruby/4.0-wasm-wasi) - All logic implemented in Ruby
- **Three.js** - 3D rendering and post-processing
- **Web Audio API** - Microphone input and frequency analysis
- **Single HTML File** - Easy deployment

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

- Run on HTTPS or localhost
- Check browser microphone permission settings

### Low Performance

- Close unnecessary browser tabs
- Enable hardware acceleration
- Close DevTools console

### Other Issues

See the "Troubleshooting" section in [CLAUDE.md](CLAUDE.md) for details

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

- Ruby code: Inside `<script type="text/ruby">` blocks
- JavaScript code: Inside `<script>` blocks

Reload the browser after making changes to see the updates

## Future Enhancements

- God Rays (crepuscular rays) effect
- Preset system
- MIDI controller support
- WebVR support
- Recording functionality

See "Future Enhancement Points" in [CLAUDE.md](CLAUDE.md) for details

## License

MIT License

## Links

- [Ruby WASM Documentation](https://ruby.github.io/ruby.wasm/)
- [Three.js](https://threejs.org/)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)

---

Made with ❤️ by Rubyists, for VJs 🎵✨
