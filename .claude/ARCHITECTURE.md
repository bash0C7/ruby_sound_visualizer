# Architecture & Implementation Details

## Data Flow

```
Microphone
  ↓
Web Audio API (JavaScript)
  - getUserMedia でマイク接続
  - AnalyserNode で周波数解析
  ↓
Ruby WASM VM
  - AudioAnalyzer: 周波数帯域分析
  - EffectManager: エフェクト管理
  - ParticleSystem: パーティクル物理演算
  - GeometryMorpher: 幾何学変形計算
  - ColorPalette: 色彩変換
  ↓
Three.js (JavaScript)
  - updateParticles: パーティクルの位置・色を更新
  - updateGeometry: トーラスのスケール・回転を更新
  ↓
WebGL Rendering
  - EffectComposer でポストエフェクト適用
```

## Serial Audio Data Flow (PicoRuby → Chrome)

```
PicoRuby (ESP32)
  ↓ USB Serial: <F:NNNNN,D:NNN>\n
Chrome Web Serial read loop
  ↓ rubySerialOnReceive(data)
Ruby WASM VM
  - SerialManager.receive_data → SerialProtocol.extract_frames
  - Frequency frame detected (type: :frequency)
  - SerialAudioSource.update(freq, duty)
  ↓ pending_update? in main loop
JavaScript
  - updateSerialAudio(freq, duty, active, volume)
  - OscillatorNode with PWM PeriodicWave
  ↓
Web Audio API
  ├→ AnalyserNode (visualization source, like mic/tab/cam)
  └→ AudioContext.destination (speaker output)
```

## Synth Audio Data Flow (PicoRuby → Chrome → Oscilloscope)

```
PicoRuby (ESP32)
  ↓ USB Serial: <F:NNNNN,D:NNN>\n
Chrome Web Serial read loop
  ↓ rubySerialOnReceive(data)
Ruby WASM VM
  - SerialManager.receive_data → SerialProtocol.extract_frames
  - Frequency frame detected (type: :frequency)
  - SerialAudioSource.update(freq, duty)  [legacy PWM path]
  - SynthEngine.note_on(freq, duty)       [synth path]
  ↓ pending_update? in main loop
JavaScript
  - updateSynthAudio(freq, duty, active, gain, waveform, attack, decay,
                     sustain, release, cutoff, resonance, filterType)
  - OscillatorNode → BiquadFilterNode → GainNode (ADSR) → AnalyserNode
  ↓
Web Audio API
  ├→ AnalyserNode (visualization + oscilloscope waveform capture)
  └→ AudioContext.destination (speaker output)
  ↓
JavaScript (oscilloscope)
  - updateOscilloscope(waveform, scrollOffset, intensity, color, zPos, yPos)
  - 256-segment THREE.Line + 48-line history ring buffer
  - Positioned at z=8, y=-2 (in front of VRM/particles)
  ↓
Three.js Rendering (renderOrder=999, foreground layer)
```

## Synth Engine (Ruby)

`SynthEngine` manages analog monophonic synthesizer state:

- **Waveform**: sine, square, sawtooth, triangle
- **ADSR Envelope**: attack (0.001-5s), decay (0.001-5s), sustain (0-1), release (0.001-5s)
- **Filter**: cutoff (20-20000 Hz), resonance/Q (0-30), type (lowpass/highpass/bandpass)
- **Note control**: note_on(freq, duty) from serial, note_off on zero duty
- **Pending update pattern**: same as SerialAudioSource for efficient JS bridge calls

VJ Pad commands: syn_w, syn_a, syn_d, syn_s, syn_r, syn_fc, syn_fq, syn_ft, syn_g, syn_i

## Oscilloscope Renderer (Ruby)

`OscilloscopeRenderer` manages 3D oscilloscope visualization state:

- **Waveform buffer**: 256 samples, clamped to [-1, 1]
- **History ring buffer**: 64 depth for 3D ribbon trail effect
- **Scroll animation**: left-to-right flow, configurable speed (0.1-10)
- **Position**: z=8 (in front of VRM/particles), y=-2
- **Intensity**: driven by synth duty cycle when active

VJ Pad commands: osc (toggle), osc_sp (scroll speed)

## Technical Stack

- **Ruby 3.4.7** (via @ruby/4.0-wasm-wasi 2.8.1)
- **Three.js** (0.160.0) - 3D rendering & post-processing
- **Web Audio API** - マイク入力 & 周波数解析 & シリアルPWM音声出力

## Audio Analysis (Ruby)

`AudioAnalyzer` クラスが周波数データを分析：

**周波数帯域の分類**:
- **Bass (0-250 Hz)**: 低音、赤色にマッピング
- **Mid (250-2000 Hz)**: 中音、緑色にマッピング
- **High (2000-20000 Hz)**: 高音、青色にマッピング

**エネルギー計算**:
- 各帯域のRMS（二乗平均平方根）を計算
- 時間ベースの平滑化（スムージング）で値の揺らぎを減少

**返却データ**:
```ruby
{
  bass: Float,              # 低音エネルギー (0-1)
  mid: Float,               # 中音エネルギー (0-1)
  high: Float,              # 高音エネルギー (0-1)
  overall_energy: Float,    # 全体エネルギー (0-1)
  dominant_frequency: Float # 最大成分の周波数 (Hz)
}
```

## Runtime Mutable Parameters (Ruby)

`VisualizerPolicy` provides 15 runtime-mutable parameters grouped into categories:

**Master**: sensitivity, exclude_max
**Bloom**: bloom_base_strength, max_bloom, bloom_energy_scale, bloom_impulse_scale
**Particles**: particle_explosion_base_prob, particle_explosion_energy_scale, particle_explosion_force_scale, particle_friction
**Rendering**: max_brightness, max_lightness, max_emissive
**Audio**: visual_smoothing, impulse_decay

These parameters can be adjusted via:
- Control Panel UI (slider-based, toggle with `p` key)
- VJ Pad DSL commands (bbs, bes, bis, pp, pf, fr, vs, id)
- DevTools console (rubyConfigSet/rubyConfigGet/rubyConfigList/rubyConfigReset)

All parameters have min/max bounds and can be reset to defaults with `r` (VJ Pad) or `rubyConfigReset()` (DevTools).

## Control Panel UI

HTML/CSS control panel overlaying the visualizer canvas:
- Toggle visibility with `p` key
- Sliders grouped by category (Bloom, Particles, Audio, Serial Audio, Camera, Capture)
- Real-time bidirectional sync with VisualizerPolicy
- Audio source buttons (Mic, Cam Mic, Tab) + Serial audio output (PWM button, output device picker)
- Preview-first startup flow (panel visible before audio starts)

## Particle System (Ruby)

10,000個のパーティクルを管理：

- **初期化**: ランダムな3D位置に配置
- **物理演算**: 速度ベースの位置更新、摩擦（速度減衰）
- **爆発エフェクト**: エネルギーが0.5を超えると、ランダム方向に飛散
- **色変化**: 周波数帯域の比率から色を計算、エネルギーで明度を変更
- **境界処理**: 一定範囲外に出たパーティクルは中央にリセット

## Geometry Morphing (Ruby)

トーラス（ドーナツ形）をリアルタイム変形：

- **スケール変化**: 全体エネルギーで拡大縮小（`scale = 1.0 + energy * 0.5`）
- **回転制御**: 各周波数帯域が異なる軸を回転（X軸: Bass, Y軸: Mid, Z軸: High）

## Color System (Ruby)

周波数帯域から色を生成：

```ruby
# 基本色定義
BASS_COLOR = [1.0, 0.0, 0.0]   # 赤
MID_COLOR = [0.0, 1.0, 0.0]    # 緑
HIGH_COLOR = [0.0, 0.0, 1.0]   # 青

# 周波数帯域の重みで色を合成
color = BASS_COLOR * bass_weight +
        MID_COLOR * mid_weight +
        HIGH_COLOR * high_weight

# エネルギーで明度を制御
brightness = 0.3 + sqrt(energy) * 1.7
```

## Plugin System

VJ Pad commands are implemented as plugins, decoupled from the core system.

### Components

- **VJPlugin** (`vj_plugin.rb`): Plugin registry and DSL for defining commands
- **PluginDefinition**: Stores name, description, parameters, and trigger logic
- **EffectDispatcher** (`effect_dispatcher.rb`): Translates plugin effect hashes into EffectManager calls

### Data Flow

```
VJPad.exec("burst 2.0")
  ↓ method_missing → VJPlugin.find(:burst)
PluginDefinition#execute({ force: 2.0 })
  ↓ returns effect hash
{ impulse: { bass: 2.0, mid: 2.0, high: 2.0, overall: 2.0 } }
  ↓ queued as pending_action
EffectDispatcher#dispatch(effects)
  ↓
EffectManager#inject_impulse(bass: 2.0, ...)
```

### Plugin Definition

```ruby
# src/ruby/plugins/vj_burst.rb
VJPlugin.define(:burst) do
  desc "Inject impulse across all frequency bands"
  param :force, default: 1.0
  on_trigger do |params|
    f = params[:force]
    { impulse: { bass: f, mid: f, high: f, overall: f } }
  end
end
```

### Available Effect Types

| Key | Target | Description |
|-----|--------|-------------|
| `impulse:` | ParticleSystem, GeometryMorpher, CameraController | Frequency band energy injection |
| `bloom_flash:` | BloomController | Bloom glow flash |
| `set_param:` | VisualizerPolicy | Runtime parameter updates |

See [Plugin Development Guide](guides/plugin-development.md) for details.

## Performance Optimization

### Particle Count Adjustment

ブラウザのパフォーマンスが低い場合、[index.html:1](../index.html#L1) 内の以下の値を変更：

**JavaScript:**
```javascript
const particleCount = 10000;  // 5000 や 3000 に減らす
```

**Ruby:**
```ruby
PARTICLE_COUNT = 10000  # 5000 や 3000 に減らす
```

### Other Optimizations

- ハードウェアアクセラレーションを有効化（Chrome/Firefox 設定）
- 他のタブを閉じる（GPU メモリ節約）
- DevTools コンソールを閉じる（描画負荷軽減）

## Single-File Architecture

すべてのコードが [index.html](../index.html) に含まれている理由：

1. **完全ブラウザベース**: サーバーサイド処理なし
2. **デプロイ簡素化**: ファイルをコピーするだけで動作
3. **CORS の回避**: ローカルファイルとして直接開く場合のセキュリティ制約を回避
4. **CDN 依存性の最小化**: ruby.wasm と Three.js CDN のみを使用

### File Structure

[index.html](../index.html):
```
HTML/CSS (lines 1-X)
  ├── Canvas と UI
  ├── Loading animation
  ├── Control Panel (audio parameter sliders)
  └── Debug info display

JavaScript (lines X-Y)
  ├── Three.js setup
  ├── Web Audio API
  ├── Synth Audio Engine (OscillatorNode + BiquadFilter + ADSR GainNode)
  ├── Oscilloscope 3D Mesh (THREE.Line + history ring buffer)
  ├── Rendering loop
  └── Communication with Ruby WASM

Ruby Code (lines Y-Z)
  ├── MathHelper
  ├── JSBridge
  ├── FrequencyMapper
  ├── AudioAnalyzer
  ├── ColorPalette
  ├── ParticleSystem
  ├── GeometryMorpher
  ├── EffectManager
  ├── BloomController
  ├── AudioInputManager
  ├── SerialAudioSource
  ├── SynthEngine (analog monophonic synth state)
  ├── OscilloscopeRenderer (3D waveform visualization state)
  ├── VisualizerPolicy (constants + mutable params)
  ├── VJPad (DSL commands + VJSynthCommands)
  └── Main (initialization & main loop)
```
