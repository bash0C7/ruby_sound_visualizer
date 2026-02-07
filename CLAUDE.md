# Ruby WASM Sound Visualizer

ブラウザで動作する、Rubyで書かれた音響ビジュアライザー（VJソフトウェア）

## 概要

マイク入力をリアルタイムで解析し、Three.jsで派手な3D視覚エフェクトを生成します。
ロジックのほぼ全てをRubyで実装し、@ruby/4.0-wasm-wasiによってブラウザで実行されます。

## 特徴

- **完全ブラウザベース**: サーバー不要、HTMLファイルを開くだけで動作
- **単一ファイル構成**: index.htmlに全てのRubyコードとJavaScriptが含まれている
- **Rubyで書かれたロジック**: 音響分析、エフェクト計算を全てRubyで実装
- **派手な視覚エフェクト**:
  - 周波数別色分け（低音=赤、中音=緑、高音=青）
  - 10,000個のパーティクルシステム（音に反応して爆発）
  - 幾何学模様の変形（トーラスが音に合わせて変形・回転）
  - 発光エフェクト（UnrealBloomPass）
- **完全自動**: マイク許可後は自動で動作、UI操作不要

## アーキテクチャ

### 技術スタック

- **Ruby 3.4.7** (via @ruby/4.0-wasm-wasi 2.8.1)
- **Three.js** (0.160.0) - 3D rendering & post-processing
- **Web Audio API** - マイク入力 & 周波数解析

### データフロー

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

## ファイル構成

```
ruby_sound_visualizer/
├── .ruby-version              # Ruby 3.4.7
├── index.html                 # 全コードを含む単一ファイル
│   ├── HTML/CSS
│   ├── Three.js/Web Audio API (JavaScript)
│   └── 埋め込みRubyコード:
│       ├── MathHelper
│       ├── JSBridge
│       ├── FrequencyMapper
│       ├── AudioAnalyzer
│       ├── ColorPalette
│       ├── ParticleSystem
│       ├── GeometryMorpher
│       ├── EffectManager
│       └── Main (初期化・メインループ)
├── src/                       # （参考用）個別ファイル（実装時のソース）
│   ├── utils/
│   ├── audio/
│   └── visuals/
└── CLAUDE.md                  # このファイル
```

## 実装の詳細

### 音響分析 (Ruby)

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

### パーティクルシステム (Ruby)

10,000個のパーティクルを管理：

- **初期化**: ランダムな3D位置に配置
- **物理演算**: 速度ベースの位置更新、摩擦（速度減衰）
- **爆発エフェクト**: エネルギーが0.5を超えると、ランダム方向に飛散
- **色変化**: 周波数帯域の比率から色を計算、エネルギーで明度を変更
- **境界処理**: 一定範囲外に出たパーティクルは中央にリセット

**更新フロー**:
```ruby
analysis = analyze(frequency_data)
particles.each do |p|
  # 爆発判定
  if energy > 0.5 && rand < 0.05
    p.velocity = random_direction * energy
  end

  # 位置更新
  p.position += p.velocity

  # 摩擦
  p.velocity *= 0.95

  # 色更新
  p.color = frequency_to_color(analysis) * energy_brightness
end
```

### 幾何学変形 (Ruby)

トーラス（ドーナツ形）をリアルタイム変形：

- **スケール変化**: 全体エネルギーで拡大縮小
  - `scale = 1.0 + energy * 0.5`

- **回転制御**: 各周波数帯域が異なる軸を回転
  - X軸: Bass 回転速度
  - Y軸: Mid 回転速度
  - Z軸: High 回転速度

### 色彩システム (Ruby)

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
```

エネルギーで明度を制御：
```ruby
brightness = 0.3 + sqrt(energy) * 1.7
```

### JavaScript ブリッジ

Ruby と JavaScript 間のデータ受け渡し：

**Ruby → JavaScript**:
```ruby
# method_missing 経由で呼ぶ（.call() は使わない。後述の「既知の問題」参照）
JS.global.updateParticles(positions_array, colors_array)
JS.global.updateGeometry(scale, rotation_array)
```

**JavaScript → Ruby**:
```ruby
JS.global[:rubyUpdateVisuals] = lambda { |freq_array| ... }
```

## 実行方法

### 前提条件

- モダンブラウザ（Chrome, Firefox, Safari, Edge）
- HTTPSまたは localhost での実行（マイク使用のため）
- WebAssembly サポート
- Ruby 3.4.7（Gemfile で指定）

### Ruby WEBrick サーバーで実行（推奨）

```bash
# 1. プロジェクトディレクトリに移動
cd ruby_sound_visualizer

# 2. Bundler で依存関係をインストール
bundle install

# 3. WEBrick サーバーを起動
bundle exec ruby -run -ehttpd . -p8000
```

ブラウザで `http://localhost:8000/index.html` を開く

### その他のサーバーオプション

**Pythonの場合**:
```bash
python3 -m http.server 8000
```

**Node.js の場合**:
```bash
npx http-server
```

### 初回実行時

1. ページを開く
2. 「Ruby WASM Sound Visualizer...」ローディング画面が表示
3. CDN から ruby.wasm とライブラリをダウンロード（初回は30秒程度かかる場合あり）
4. ブラウザがマイク使用の許可を求めてくる → 「許可」をクリック
5. マイクに音が入ると、自動的にビジュアルが動作開始

### 動作確認

- 音楽を再生してマイク付近で流す
- パーティクルが音に反応して爆発するか確認
- トーラスが拡大縮小・回転するか確認
- パーティクルの色が周波数に応じて変わるか確認
- 画面全体が発光するか確認（Bloom エフェクト）

## パフォーマンス最適化

### パーティクル数の調整

ブラウザのパフォーマンスが低い場合、index.html 内の以下の値を変更：

```javascript
const particleCount = 10000;  // 5000 や 3000 に減らす
```

```ruby
PARTICLE_COUNT = 10000  # 5000 や 3000 に減らす
```

### ブラウザ設定

- ハードウェアアクセラレーションを有効化（Chrome/Firefox 設定）
- 他のタブを閉じる（GPU メモリ節約）
- DevTools コンソールを閉じる（描画負荷軽減）

## トラブルシューティング

### Ruby WASM が読み込めない

**症状**: 「Error: Failed to fetch ruby.wasm」

**原因**: CORS エラー または ネットワークエラー

**解決法**:
- ローカルサーバー（http://localhost:8000）で実行
- インターネット接続を確認
- ブラウザコンソール（F12）でエラー詳細を確認

### マイクが動作しない

**症状**: 「Permission denied」または マイク許可ダイアログが出ない

**原因**: HTTPS でない、またはセキュリティ設定

**解決法**:
- HTTPS または localhost で実行（非 HTTPS では マイク使用不可）
- ブラウザのマイク許可設定を確認：
  - Chrome: 左上のロックアイコン → サイト設定 → マイク → 許可
  - Firefox: メニュー → 設定 → プライバシーとセキュリティ → マイク → 許可

### パフォーマンスが悪い

**症状**: FPS が低い（20 以下）、描画が遅い

**原因**: GPU 不足、または パーティクル数が多すぎる

**解決法**:
1. パーティクル数を 5000 に減らす
2. ブラウザのタブを少なくする
3. ハードウェアアクセラレーションを有効化

### Ruby エラーが出ている

**症状**: コンソールに「[Ruby] Error:...」というメッセージ

**確認**:
- ブラウザの DevTools コンソール（F12）を開く
- エラーメッセージを確認
- ローカルサーバーで実行しているか確認

## 今後の拡張ポイント

### ビジュアルエフェクト

- **God Rays（薄明光線）**: ShaderPass で光線効果を追加
- **Chromatic Aberration（色収差）**: 迫力ある色分離エフェクト
- **Camera Shake**: 強い低音で カメラを揺動
- **Trail Effect**: パーティクルの軌跡表示
- **Post-processing**: グリッチエフェクト、ノイズ、モーションブラー

### 機能拡張

- **プリセットシステム**: 複数のビジュアルスタイルを切り替え可能
- **録画機能**: Canvas Stream API でビデオ出力
- **MIDI 対応**: 外部 MIDI コントローラーでパラメータ制御
- **VR モード**: WebXR API でVRヘッドセット対応
- **周波数ビジュアライザー**: スペクトラム表示

### パフォーマンス改善

- **WebWorker**: 音響分析を別スレッドで実行
- **GPU 計算**: GLSL シェーダーでのパーティクル計算
- **LOD（Level of Detail）**: 距離に応じたパーティクル数動的調整
- **テクスチャ活用**: パーティクル描画を2D テクスチャで高速化

## 開発ノート

### Ruby WASM との相互運用

Ruby WASM では以下を使用して JavaScript と連携：

```ruby
# JavaScript グローバルオブジェクトへのアクセス
window = JS.global[:window]
console = JS.global[:console]

# JavaScript メソッドの呼び出し
console.log("message")

# JavaScript オブジェクトの生成
three_scene = JS.global[:THREE][:Scene].new

# Ruby のコールバックを JavaScript に登録
JS.global[:rubyCallback] = lambda { |data| ... }
```

### 既知の問題: JS::Object#call のバグ（js gem 2.8.1）

**`JS::Object#call` でJS関数を呼ぶと TypeError になる。`method_missing` 経由なら動く。**

```ruby
# NG: JS::Object#call → 内部の Reflect.apply で関数参照が undefined に化ける
js_func = JS.global[:updateParticles]
js_func.typeof   # => "function"（参照自体は有効）
js_func.call(a, b)  # => TypeError: Function.prototype.apply was called on undefined

# OK: method_missing → invoke_js_method 経由で正しく動く
JS.global.updateParticles(a, b)  # 成功！
```

**原因**: `#call` は内部保持した関数参照を `Reflect.apply` に渡すが、その参照が `undefined` に化ける。
`method_missing` は `globalThis` から関数を都度解決して `invoke_js_method` で呼ぶため問題なし。

### JS::Object の注意点

`JS::Object` は **`BasicObject` を継承**している：

- `.class`, `.nil?`, `.is_a?` 等の Ruby 組み込みメソッドは **存在しない**
- 全て `method_missing` 経由で **JS プロパティアクセスに変換**される
- デバッグには `.typeof`（JS::Object 固有メソッド）を使う
- 文字列補間内で `.class` を呼ぶと `obj.class` というJSプロパティアクセスになり `NoMethodError` で落ちる

```ruby
js_obj = JS.global[:someFunc]
js_obj.typeof   # => "function" （OK: JS::Object 固有メソッド）
js_obj.class    # => NoMethodError （NG: BasicObject に .class はない → method_missing → JS の obj.class を探す → 存在しない）
```

### パフォーマンスのボトルネック

1. **パーティクル更新**: 10,000 個 × フレーム数のループが最大の負荷
2. **周波数解析**: FFT 計算（JavaScript で実施）
3. **BufferAttribute 更新**: needsUpdate フラグの管理が重要

### 設計上の制約

- **単一ファイル**: CDN への依存を最小化、デプロイが簡単
- **YAGNI 原則**: 不要な機能は追加しない（今後の拡張時に追加予定）
- **マイク必須**: ビジュアルはマイク入力に完全に依存

## デバッグの手引き

### ブラウザでの確認方法

1. ローカルサーバーを起動: `bundle exec ruby -run -ehttpd . -p8000`
2. ブラウザで `http://localhost:8000/index.html` を開く
3. DevTools コンソール（F12）でエラーを確認
4. Ruby WASM の初期化には **20〜30秒**かかるため、待ってから確認すること

### Ruby WASM コードのデバッグ出力

```ruby
# OK: console.log/error は method_missing 経由で安全に呼べる
JS.global[:console].log("[DEBUG] value=#{some_value}")

# OK: typeof は JS::Object 固有メソッド
JS.global[:console].log("[DEBUG] typeof=#{js_obj.typeof}")

# NG: .class, .nil?, .inspect 等は使えない（BasicObject 継承のため）
JS.global[:console].log("class=#{js_obj.class}")  # NoMethodError で落ちる
```

### JS側でのエラー監視（プログラム的）

DevTools を開けない状況では、JS 側で `console.error` をフックして監視できる：

```javascript
window._errorCount = 0;
window._errorMessages = [];
const origError = console.error;
console.error = function(...args) {
  window._errorCount++;
  if (window._errorMessages.length < 5) {
    window._errorMessages.push(args.map(a => String(a).substring(0, 200)).join(' '));
  }
  origError.apply(console, args);
};
// 後で確認: JSON.stringify({ errorCount: window._errorCount, errors: window._errorMessages })
```

### 問題の洗い出し方

1. **まず事実を掴む**: 憶測で修正しない。`console.log` でデバッグ出力を入れて、実際の値を確認する
2. **エラーメッセージを正確に読む**: ruby.wasm のスタックトレースは `eval:行番号` で `<script type="text/ruby">` ブロック内の行を指す
3. **一つずつ変数を確認**: 複数の値を一度に出力しようとすると、途中で例外が出て全体が失敗する（例: `.typeof` は OK だが `.class` で落ちる）
4. **仮説を立てて検証**: 例えば「`.call()` が駄目なら `method_missing` はどうか？」のように、代替手段を一つずつ試す
5. **Chrome で確認**: ページリロード後 Ruby WASM の初期化に時間がかかるため、**25〜30秒待ってから**コンソールを確認する

### 実装のコツ

- **Ruby → JS 関数呼び出し**: 必ず `JS.global.funcName(args)` 形式を使う（`method_missing` 経由）。`.call()` は使わない
- **JS → Ruby コールバック**: `JS.global[:name] = lambda { |args| ... }` で登録。JS 側から `window.name(args)` で呼べる
- **JS Array の受け取り**: Ruby lambda の引数として渡された JS Array は `.to_a` で Ruby Array に変換できる
- **Ruby Array の受け渡し**: Ruby Array をそのまま JS 関数に渡せる。JS 側で `Array.from()` で変換可能
- **URL のキャッシュ回避**: ブラウザ確認時は `?nocache=N` をクエリパラメータに付けてリロードすると確実

## ライセンス

MIT License

## 参考資料

- [ruby.wasm Official Documentation](https://ruby.github.io/ruby.wasm/)
- [Three.js Documentation](https://threejs.org/docs/)
- [Web Audio API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [JavaScript Interop - ruby.wasm](https://ruby.github.io/ruby.wasm/JS.html)
- [UnrealBloomPass Example](https://threejs.org/examples/?q=bloom#webgl_postprocessing_unreal_bloom)
