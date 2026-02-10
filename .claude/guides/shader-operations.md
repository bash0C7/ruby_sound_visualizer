# シェーダー操作ガイド

Three.js のポストプロセッシングとマテリアルシステムを使った映像表現の技術ガイド。

## 目次

1. [ポストプロセッシングの基礎](#ポストプロセッシングの基礎)
2. [UnrealBloomPass](#unrealbloompass)
3. [マテリアルと発光 (Emissive)](#マテリアルと発光-emissive)
4. [合成モード (Blending)](#合成モード-blending)
5. [ソフトクリッピング技法](#ソフトクリッピング技法)
6. [参考リンク](#参考リンク)

## ポストプロセッシングの基礎

Three.js のポストプロセッシングは、レンダリング結果の画像に対して追加の画像処理を施す仕組み。EffectComposer が複数の Pass を順番に実行する。

### EffectComposer の構造

```
EffectComposer
  ├── RenderPass        … シーンを通常描画してフレームバッファに書き出す
  ├── 各種エフェクト Pass … フレームバッファの画像を加工
  └── OutputPass        … トーンマッピングと最終出力
```

各 Pass はフレームバッファ (テクスチャ) の読み書きでチェーンされ、最終的に画面に表示される。

### 主要な Pass の種類

| Pass | 用途 |
|------|------|
| `RenderPass` | Three.js シーンの通常描画 |
| `UnrealBloomPass` | Bloom (グロー) エフェクト |
| `OutputPass` | トーンマッピングと出力 |
| `ShaderPass` | カスタム GLSL シェーダーの適用 |
| `SMAAPass` | アンチエイリアシング |

## UnrealBloomPass

UE4 の Bloom アルゴリズムを移植したポストプロセッシングパス。明るい部分から光がにじみ出る効果を実現する。

### パラメーター

| パラメーター | 型 | 説明 |
|------------|-----|------|
| `resolution` | `Vector2` | エフェクトの解像度 |
| `strength` | `float` | Bloom の強度。大きいほど光の滲みが強くなる |
| `radius` | `float` | Bloom の広がり半径。大きいほど遠くまで滲む |
| `threshold` | `float` | この輝度以上のピクセルのみ Bloom 対象。0.0 で全ピクセル対象 |

### strength の効果

- `0.0`: Bloom なし
- `0.5-1.5`: 控えめな発光
- `1.5-3.0`: 明確な発光感
- `3.0-5.0`: 強いグロー (ホワイトアウト注意)

### threshold の効果

- `0.0`: 全マテリアルが Bloom 対象 (暗い部分も微かに光る)
- `0.5`: 中程度の明るさ以上が対象
- `1.0`: 非常に明るい部分のみ対象

threshold を低くすると VRM モデルなど emissiveIntensity が低いオブジェクトにも Bloom が掛かる。

### 動的パラメーター変更

```javascript
bloomPass.strength = newStrength;
bloomPass.threshold = newThreshold;
// radius は通常固定で運用
```

毎フレーム値を更新するだけで即座に反映される。

## マテリアルと発光 (Emissive)

Three.js の `MeshStandardMaterial` は物理ベースレンダリング (PBR) マテリアルで、以下の発光関連プロパティを持つ。

### Emissive (発光) プロパティ

| プロパティ | 型 | 説明 |
|----------|-----|------|
| `emissive` | `Color` | 発光色。照明に関係なくこの色で光る |
| `emissiveIntensity` | `float` | 発光の強度。0.0 で無発光 |
| `emissiveMap` | `Texture` | 発光テクスチャ (任意) |

### Bloom との関係

UnrealBloomPass は画面上の明るいピクセルに対して処理する。そのため:

- `emissive` + `emissiveIntensity` で明るく描画されたピクセルが Bloom の対象になる
- `emissiveIntensity` を動的に変更することで、音に合わせた発光アニメーションが実現できる
- `emissive` を白 (`0xffffff`) にすると、元の色味を保ちつつ均一に発光する

### MeshStandardMaterial の主要プロパティ

| プロパティ | 効果 |
|----------|------|
| `metalness` | 0.0=非金属 (拡散光優位), 1.0=金属 (反射光優位) |
| `roughness` | 0.0=鏡面, 1.0=粗い表面 |
| `wireframe` | true でワイヤーフレーム表示 |
| `transparent` | true で透明度を有効化 |
| `opacity` | 透明度 (0.0-1.0) |

### PointsMaterial (パーティクル用)

| プロパティ | 効果 |
|----------|------|
| `size` | パーティクルの表示サイズ |
| `vertexColors` | true で頂点ごとの個別色を使用 |
| `blending` | 合成モード (後述) |
| `transparent` | true で透明度を有効化 |

## 合成モード (Blending)

パーティクルやオーバーレイでは合成モードが映像表現に大きく影響する。

| モード | 式 | 効果 |
|-------|-----|------|
| `NormalBlending` | 通常のアルファブレンド | 一般的な描画 |
| `AdditiveBlending` | dst + src | 色が加算される。重なるほど明るくなる |
| `SubtractiveBlending` | dst - src | 色が減算される。暗くなる |
| `MultiplyBlending` | dst * src | 色が乗算される |

AdditiveBlending はパーティクルシステムで特に有効:
- パーティクルの密集部が自然に明るくなる
- 黒背景では不透明度を下げても自然に見える
- 光の積み重なり表現に適している

## ソフトクリッピング技法

音量に比例してエフェクト強度を上げると、大音量時にホワイトアウト (画面全体が真っ白になる) が発生する。これを防ぐために tanh (双曲線正接) によるソフトクリッピングを使う。

### Math.tanh の特性

```
入力 → 出力:
  0.0  →  0.00
  0.5  →  0.46
  1.0  →  0.76
  2.0  →  0.96
  3.0  →  0.995 (ほぼ飽和)
```

- 出力は必ず -1.0 ~ 1.0 の範囲に収まる
- 入力が大きくなっても出力は緩やかに 1.0 に漸近する
- 小さい入力ではほぼ線形 (自然な応答)
- 大きい入力では飽和 (過剰な反応を抑制)

### 適用パターン

```
# 基本パターン: base + tanh(input * sensitivity) * range
output = base_value + Math.tanh(input * gain) * max_range
```

- `base_value`: 無音時の最低値
- `gain`: 感度 (大きいほど小さい入力で飽和に近づく)
- `max_range`: tanh 出力に掛けるスケール

### tanh vs clamp

| 手法 | 挙動 | 適用場面 |
|------|------|---------|
| `clamp(value, min, max)` | 範囲外で値が一定 (不連続) | デジタル的な制限 |
| `tanh(value)` | 滑らかに飽和 (連続) | 自然な映像表現 |

音響ビジュアライザーでは、急な値の変化がちらつきの原因になるため、tanh による滑らかな飽和が適している。

## 参考リンク

- [Three.js EffectComposer](https://threejs.org/docs/#examples/en/postprocessing/EffectComposer)
- [Three.js UnrealBloomPass](https://threejs.org/examples/#webgl_postprocessing_unreal_bloom)
- [Three.js MeshStandardMaterial](https://threejs.org/docs/#api/en/materials/MeshStandardMaterial)
- [Three.js PointsMaterial](https://threejs.org/docs/#api/en/materials/PointsMaterial)
- [Three.js Blending Constants](https://threejs.org/docs/#api/en/constants/Materials)
