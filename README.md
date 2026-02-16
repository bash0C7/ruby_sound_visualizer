# Ruby WASM Sound Visualizer

Browser-based audio visualizer (VJ software) written mostly in Ruby and executed in the browser through ruby.wasm.

## Quick Start

### 1. Install dependencies

```bash
bundle install
```

### 2. Start the local server

```bash
bundle exec rake server:start
```

### 3. Open in browser

```text
http://localhost:8000/index.html
```

### 4. Grant device permissions

Allow microphone access when the browser asks.

### 5. Stop the server when done

```bash
bundle exec rake server:stop
```

## Keyboard Controls

### Main controls

| Key | Function |
|---|---|
| `p` | Toggle control panel |
| `m` | Toggle mic mute |
| `Alt+V` | Toggle VRM load/unload |
| `Alt+T` | Toggle tab capture |
| `Alt+C` | Toggle camera video capture |

### Camera controls

| Key | Function |
|---|---|
| `d` / `f` | Orbit camera left / right |
| `e` / `c` | Orbit camera up / down |
| `a` / `s` | Move camera X - / + |
| `w` / `x` | Move camera Y + / - |
| `q` / `z` | Move camera Z + / - |

### Visual parameter controls

| Key | Function |
|---|---|
| `0` | Color mode: Gray |
| `1` | Color mode: Red |
| `2` | Color mode: Yellow |
| `3` | Color mode: Blue |
| `4` / `5` | Hue shift -5 / +5 degrees |
| `6` / `7` | Max brightness -5 / +5 |
| `8` / `9` | Max lightness -5 / +5 |
| `-` / `+` | Sensitivity -0.05 / +0.05 |

## Control Panel

Press `p` to open the right-side control panel.

The panel includes:
- live sliders for `VisualizerPolicy` runtime parameters
- color mode buttons and hue wheel
- VJ Pad input with quick trigger buttons
- VRM / capture / performance-view action buttons
- serial connect UI and auto-TX toggle
- audio source toggles (Mic, Cam Mic, Tab)

Note: in current UI, the mode button label `Green` maps to `c 2` (the yellow-spectrum mode used by runtime logic/tests).

## VJ Pad Commands

Use the VJ Pad input inside the control panel.

### Core commands

| Command | Description |
|---|---|
| `c <mode>` | Color mode (`0` gray, `1` red, `2` yellow, `3` blue) |
| `h <deg>` | Hue offset |
| `s <value>` | Sensitivity |
| `br <value>` | Max brightness |
| `lt <value>` | Max lightness |
| `em <value>` | Max emissive |
| `bm <value>` | Max bloom |
| `x` | Toggle cap bypass (`exclude_max`) |
| `i` | Show current summary |
| `r` | Reset runtime values |

### Audio-reactive tuning commands

| Command | Description |
|---|---|
| `bbs <value>` | Bloom base strength |
| `bes <value>` | Bloom energy scale |
| `bis <value>` | Bloom impulse scale |
| `pp <value>` | Particle explosion base probability |
| `pf <value>` | Particle explosion force scale |
| `fr <value>` | Particle friction |
| `vs <value>` | Visual smoothing |
| `id <value>` | Impulse decay |

### Input and overlay commands

| Command | Description |
|---|---|
| `mic [1/0]` | Get or set mic mute state |
| `tab [1/0]` | Get status or toggle tab capture |
| `wa <text>` | Trigger WordArt text animation |
| `was` | Stop WordArt animation |
| `pc` | Clear pen strokes |

### Serial commands

| Command | Description |
|---|---|
| `sc` | Connect serial |
| `sd` | Disconnect serial |
| `ss "text"` | Send text |
| `sr [n]` | Show RX log |
| `st [n]` | Show TX log |
| `sb [baud]` | Get/set baud rate (`38400` or `115200`) |
| `si` | Show serial status |
| `sa [1/0]` | Get/set auto-send audio frames |
| `scl [all/rx/tx]` | Clear logs |

### Plugin discovery and effect plugins

| Command | Description |
|---|---|
| `plugins` | List registered plugins |
| `burst [force]` | Inject impulse on all bands |
| `flash [intensity]` | Trigger bloom flash |
| `shockwave [force]` | Bass-heavy impulse + bloom |
| `strobe [intensity]` | Quick bloom strobe |
| `rave [level]` | Impulse + bloom + parameter boost preset |

### Command behavior

- Multiple commands can be chained with semicolons: `c 1; s 1.5; flash`
- Getter form is available for many commands by omitting arguments: `s`, `h`, `bm`, `si`
- Color aliases are supported: `:red/:r`, `:yellow/:y`, `:blue/:b`, `:gray/:g`
- `wa` accepts unquoted text and auto-quotes it internally

## URL Parameters

### Basic startup parameters

```text
http://localhost:8000/index.html?sensitivity=1.5&maxBrightness=200&maxLightness=180
```

| Parameter | Description | Default |
|---|---|---|
| `sensitivity` | Sensitivity multiplier | `1.0` |
| `maxBrightness` | RGB cap (0-255) | `255` |
| `maxLightness` | HSV value cap (0-255) | `255` |

### Snapshot parameters

The app also writes a URL snapshot schema (`v`, `hue`, `mode`, `brt`, `sat`, `sens`, `bbs`, `bmax`, `bes`, `bis`, `pp`, `pes`, `pfs`, `fr`, `ml`, `me`, `vs`, `id`, `cr`, `cth`, `cph`, plus capture opacity keys) when control values change.

## Features

- Ruby-first visual logic running in browser via ruby.wasm
- 3000 audio-reactive particles with additive blending
- Audio-reactive torus geometry scale, rotation, color, and emissive
- Bloom post-processing driven by energy and impulse
- Beat-driven impulse pipeline via `AudioAnalyzer` + `EffectManager`
- VRM load/unload, dance animation, and emissive material updates
- WordArt overlay animation renderer
- Pen drawing overlay with fade-out and palette-synced colors
- Web Serial integration with ASCII frame protocol
- Runtime config sliders and DevTools config API
- URL snapshot encode/apply for scene + runtime state
- Optional performance-view window sync

## Technology

- Ruby 3.4.7 via `@ruby/4.0-wasm-wasi@2.8.1`
- Three.js `0.160.0`
- `@pixiv/three-vrm` `3.x`
- Web Audio API for analyzer input
- Web Serial API for hardware output

## File Structure

```text
ruby_sound_visualizer/
├── index.html
├── src/ruby/
│   ├── main.rb
│   ├── visualizer_policy.rb
│   ├── math_helper.rb
│   ├── js_bridge.rb
│   ├── frequency_mapper.rb
│   ├── audio_limiter.rb
│   ├── audio_analyzer.rb
│   ├── audio_input_manager.rb
│   ├── color_palette.rb
│   ├── particle_system.rb
│   ├── geometry_morpher.rb
│   ├── camera_controller.rb
│   ├── bloom_controller.rb
│   ├── effect_manager.rb
│   ├── effect_dispatcher.rb
│   ├── keyboard_handler.rb
│   ├── vj_plugin.rb
│   ├── vj_serial_commands.rb
│   ├── vj_pad.rb
│   ├── serial_protocol.rb
│   ├── serial_manager.rb
│   ├── serial_audio_source.rb
│   ├── pen_input.rb
│   ├── wordart_renderer.rb
│   ├── debug_formatter.rb
│   ├── bpm_estimator.rb
│   ├── frame_counter.rb
│   ├── vrm_dancer.rb
│   ├── vrm_material_controller.rb
│   ├── snapshot_manager.rb
│   └── plugins/
│       ├── vj_burst.rb
│       ├── vj_flash.rb
│       ├── vj_shockwave.rb
│       ├── vj_strobe.rb
│       ├── vj_rave.rb
│       ├── vj_serial.rb
│       └── vj_wordart.rb
├── test/
├── picoruby/
├── .claude/
├── Gemfile
├── Rakefile
└── README.md
```

## Troubleshooting

### No audio reaction

- Check mic permission in browser site settings
- Click once on page if AudioContext stays suspended
- Confirm an audio source is active (Mic, Cam Mic, or Tab)

### Tab or camera capture does not start

- Use `Alt+T` for tab capture and `Alt+C` for camera capture
- Make sure the browser/device permission prompt is approved

### Serial does not send

- Confirm Web Serial is supported in your browser
- Connect first (`sc`) and verify with `si`
- Check auto-send status with `sa`

### Visuals too bright or dim

- Adjust `maxBrightness`, `maxLightness`, and `max_bloom`
- Use `r` to reset runtime tuning quickly
