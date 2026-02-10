# ruby.wasm 技術ガイド

ruby.wasm プラットフォームの技術仕様、制約、ブラウザでの実行環境について解説する。

## 目次

1. [ruby.wasm とは](#rubywasm-とは)
2. [ブラウザへの組み込み方法](#ブラウザへの組み込み方法)
3. [利用可能な機能と制約](#利用可能な機能と制約)
4. [Web Audio API との統合](#web-audio-api-との統合)
5. [パフォーマンス特性](#パフォーマンス特性)
6. [開発とテスト](#開発とテスト)
7. [トラブルシューティング](#トラブルシューティング)
8. [参考リンク](#参考リンク)

## ruby.wasm とは

ruby.wasm は CRuby インタープリタを WebAssembly (WASM) にコンパイルしたもの。ブラウザ上で Ruby コードを実行できる。

### 主要コンポーネント

| コンポーネント | 説明 |
|-------------|------|
| `@ruby/wasm-wasi` | Ruby WASM バイナリ (WASI 対応) |
| `browser.script.iife.js` | ブラウザ統合スクリプト (`<script type="text/ruby">` サポート) |
| `js` gem | JavaScript 相互運用 (ruby.wasm に組み込み) |

### バージョン体系

```
@ruby/4.0-wasm-wasi@2.8.1
  │    │           │
  │    │           └── パッケージバージョン
  │    └── WASI バージョン
  └── Ruby メジャーバージョン系列
```

Ruby 3.4.x ベースの場合、`@ruby/4.0-wasm-wasi` を使用。

## ブラウザへの組み込み方法

### 基本構成

```html
<!-- 1. ruby.wasm ランタイムの読み込み (必ず最初) -->
<script src="https://cdn.jsdelivr.net/npm/@ruby/4.0-wasm-wasi@2.8.1/dist/browser.script.iife.js"></script>

<!-- 2. Ruby コードの埋め込み (インライン) -->
<script type="text/ruby">
  require 'js'
  JS.global[:console].log("Hello from Ruby!")
</script>

<!-- 3. Ruby コードの読み込み (外部ファイル) -->
<script type="text/ruby" src="app.rb"></script>
```

### 読み込み順序の重要性

1. `browser.script.iife.js` が最初に読み込まれる必要がある
2. `type="text/ruby"` スクリプトは上から順に実行される
3. 依存関係のあるファイルは先に読み込む (ユーティリティ → メイン)

### Import Maps との共存

ruby.wasm のスクリプトと ES Modules (Three.js 等) を共存させる場合:

```html
<!-- ruby.wasm (IIFE, 通常のスクリプト) -->
<script src="browser.script.iife.js"></script>

<!-- Import Maps (ES Modules 用) -->
<script type="importmap">
{
  "imports": {
    "three": "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js"
  }
}
</script>

<!-- ES Module (type="module" でグローバル登録) -->
<script type="module">
  import * as THREE from 'three';
  window.THREE = THREE;         // Ruby から使えるようにグローバル登録
  window.THREE_READY = true;    // 準備完了フラグ
</script>

<!-- Ruby コード (THREE_READY を待ってから使用) -->
<script type="text/ruby" src="main.rb"></script>
```

## 利用可能な機能と制約

### 使える機能

| 機能 | 状態 | 備考 |
|------|------|------|
| Ruby 標準ライブラリ (Array, Hash, String 等) | 使用可 | フル機能 |
| 数学関数 (Math モジュール) | 使用可 | sin, cos, tanh, sqrt 等 |
| 正規表現 | 使用可 | Ruby String に変換してから使用 |
| クラス定義 | 使用可 | 通常通り |
| モジュール | 使用可 | 通常通り |
| ブロック / lambda / Proc | 使用可 | JavaScript コールバックに利用 |
| `require 'js'` | 使用可 | JavaScript 連携用 (組み込み) |

### 使えない / 制限がある機能

| 機能 | 状態 | 理由 |
|------|------|------|
| ファイル I/O | 制限あり | WASI の仮想ファイルシステム内のみ |
| ネットワーク (Net::HTTP 等) | 使用不可 | WASM サンドボックス制約 |
| 外部 gem (bundler) | 使用不可 | ブラウザ環境では gem install 不可 |
| スレッド | 制限あり | Web Workers との統合が必要 |
| system / exec | 使用不可 | サンドボックス制約 |
| require (ファイルベース) | 制限あり | `<script type="text/ruby">` での読み込みが代替 |

### gem の扱い

ブラウザ環境では外部 gem は使用できない。全てのロジックを Ruby 標準ライブラリのみで実装する必要がある。ただし `js` gem は ruby.wasm に組み込みのため、`require 'js'` は常に利用可能。

ローカル開発サーバー用には Gemfile で webrick 等を管理できるが、これらはブラウザで実行されるコードとは無関係。

## Web Audio API との統合

### アーキテクチャパターン

```
マイク → AudioContext → AnalyserNode → 周波数データ (JS Array)
                                          ↓
                                     Ruby コールバック
                                          ↓
                                     Ruby で分析・計算
                                          ↓
                                     JS 描画関数を呼ぶ
```

### AnalyserNode の主要パラメーター

| パラメーター | 説明 | 推奨値 |
|------------|------|-------|
| `fftSize` | FFT のウィンドウサイズ | 2048 (周波数分解能 ≈ 23Hz) |
| `smoothingTimeConstant` | 時間軸の平滑化 | 0.5 (ビート検出には低めが良い) |
| `frequencyBinCount` | 周波数ビン数 (fftSize/2) | 1024 |

### 周波数帯域の分類

サンプルレート 48kHz、FFT サイズ 2048 の場合:

```
1 ビンの幅 = (48000 / 2) / 1024 ≈ 23.4 Hz

低音 (Bass):    0-250 Hz    → ビン 0-10
中音 (Mid):   250-2000 Hz   → ビン 11-85
高音 (High): 2000-20000 Hz  → ビン 86-853
```

### getByteFrequencyData

```javascript
const dataArray = new Uint8Array(analyser.frequencyBinCount);
analyser.getByteFrequencyData(dataArray);
// dataArray: 0-255 の整数値 (0=無音, 255=最大)
```

この配列を Ruby コールバックに渡し、Ruby 側で分析する。

### Chrome のオートプレイポリシー

Chrome はユーザー操作なしに AudioContext を開始できない:

```javascript
// 作成直後は suspended 状態
const ctx = new AudioContext();
// state === 'suspended'

// 明示的に resume が必要
await ctx.resume();

// フォールバック: ユーザークリックで resume
document.addEventListener('click', () => {
  if (ctx.state === 'suspended') ctx.resume();
}, { once: true });
```

## パフォーマンス特性

### WASM の実行速度

ruby.wasm の実行速度はネイティブ Ruby の約 3-10 倍遅い (処理内容に依存)。毎フレーム実行される処理では:

1. 不要な配列コピーを避ける
2. 文字列生成を最小化する
3. Ruby-JS 境界の呼び出し回数を減らす

### 初回ロード時間

ruby.wasm ランタイムのダウンロードと初期化に時間がかかる:

- WASM バイナリ: 約 10-20 MB (CDN からの初回ダウンロード)
- 初期化: ブラウザとネットワーク環境に依存
- 2 回目以降: ブラウザキャッシュが効く

ローディング画面を表示して待機させるのが一般的。

### メモリ使用量

WASM は線形メモリモデルを使用し、Ruby ヒープ全体がこの中に収まる。大量のオブジェクト生成は GC 頻度を上げ、パフォーマンスに影響する。

## 開発とテスト

### ローカル開発サーバー

ruby.wasm は HTTP(S) 経由でのアクセスが必要 (`file://` プロトコルでは動作しない):

```bash
# Ruby の webrick を使う
bundle exec ruby -run -ehttpd . -p8000

# Python でも可
python3 -m http.server 8000
```

`http://localhost:8000/index.html` でアクセス。

### ユニットテスト

ブラウザに依存しないロジック (計算、データ変換等) は通常の Ruby テストフレームワークでテストできる:

```ruby
# test/test_my_class.rb
require 'test-unit'
require_relative '../src/ruby/my_class'

class TestMyClass < Test::Unit::TestCase
  def test_calculation
    assert_equal 42, MyClass.calculate(input)
  end
end
```

ただし `require 'js'` を含むコードはブラウザ外では実行できない。`js` gem への依存を分離する設計が重要:

- 計算ロジック: `js` gem 不要 → ユニットテスト可能
- JS ブリッジ: `js` gem 必要 → ブラウザでのみテスト

### キャッシュ回避

開発中にブラウザキャッシュが残って古いコードが実行されることがある:

```
http://localhost:8000/index.html?nocache=12345
```

クエリパラメーターを変えることでキャッシュを回避できる。

## トラブルシューティング

### 画面が真っ白/真っ黒

| 症状 | 原因 | 対処 |
|------|------|------|
| 真っ黒 | Three.js の初期化失敗 | コンソールでエラー確認 |
| 真っ黒 | 照明がない (PBR マテリアル使用時) | DirectionalLight + AmbientLight を追加 |
| 真っ白 | Bloom の strength が高すぎる | strength を下げる |
| 真っ白 | emissiveIntensity が高すぎる | 値を制限する |

### Ruby コードが実行されない

| 症状 | 原因 | 対処 |
|------|------|------|
| 無反応 | browser.script.iife.js の読み込み失敗 | ネットワークタブで確認 |
| 無反応 | Ruby ファイルの読み込み順序 | 依存関係を確認 |
| エラー | `require 'js'` の記載漏れ | js_bridge 等の先頭に追加 |
| TypeError | JS::Object#call() のバグ | method_missing パターンに変更 |

### 音が拾えない

| 症状 | 原因 | 対処 |
|------|------|------|
| 無音 | マイクの許可ダイアログ未承認 | ブラウザの許可設定を確認 |
| 無音 | AudioContext が suspended | resume() を呼ぶ / クリックする |
| 小さい | sensitivity が低い | URL パラメーターか +/- キーで調整 |

## 参考リンク

- [ruby.wasm 公式ドキュメント](https://ruby.github.io/ruby.wasm/)
- [ruby.wasm GitHub](https://github.com/aspect-build/aspect-cli)
- [WebAssembly 仕様](https://webassembly.org/)
- [WASI (WebAssembly System Interface)](https://wasi.dev/)
- [Web Audio API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [AnalyserNode - MDN](https://developer.mozilla.org/en-US/docs/Web/API/AnalyserNode)
