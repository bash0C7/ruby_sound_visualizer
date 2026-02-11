# VRM 関連ガイド

VRM (Virtual Reality Model) の仕様と Three.js での活用方法を解説する。

## 目次

1. [VRM とは](#vrm-とは)
2. [VRM のファイル構造](#vrm-のファイル構造)
3. [Three.js での VRM ロード](#threejs-での-vrm-ロード)
4. [ヒューマノイドボーン](#ヒューマノイドボーン)
5. [表情 (Expression)](#表情-expression)
6. [スプリングボーン](#スプリングボーン)
7. [マテリアル制御](#マテリアル制御)
8. [VRM アニメーションの実装パターン](#vrm-アニメーションの実装パターン)
9. [参考リンク](#参考リンク)

## VRM とは

VRM は VR/AR アバター向けの 3D モデルフォーマット。glTF 2.0 をベースに、人型モデル特有のメタデータ (ボーン定義、表情、揺れもの等) を拡張仕様として追加している。

- ファイル拡張子: `.vrm`
- ベースフォーマット: glTF 2.0 Binary (.glb)
- 仕様バージョン: VRM 0.x / VRM 1.0
- 主な用途: VRChat, バーチャル配信, 3D アプリケーション

## VRM のファイル構造

```
.vrm ファイル (glTF Binary)
  ├── メッシュデータ (頂点, ポリゴン, UV)
  ├── マテリアル (テクスチャ, シェーダー設定)
  ├── スケルトン (ボーン階層)
  └── VRM 拡張データ
      ├── Meta (著作者情報, ライセンス)
      ├── Humanoid (ヒューマノイドボーンマッピング)
      ├── Expressions (表情ブレンドシェイプ)
      ├── SpringBone (揺れもの物理)
      └── Materials (MToon, Unlit 等)
```

## Three.js での VRM ロード

### 必要なライブラリ

| ライブラリ | バージョン | 用途 |
|----------|----------|------|
| `three` | 0.160.0+ | 3D レンダリング |
| `@pixiv/three-vrm` | 3.x | VRM のパース・制御 |

### ロード手順

```javascript
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { VRMLoaderPlugin, VRMUtils } from '@pixiv/three-vrm';

// 1. GLTFLoader に VRM プラグインを登録
const loader = new GLTFLoader();
loader.register((parser) => new VRMLoaderPlugin(parser));

// 2. ファイルをパース
loader.parse(arrayBuffer, '', (gltf) => {
  const vrm = gltf.userData.vrm;

  // 3. 不要な頂点・ジョイントを削除 (パフォーマンス向上)
  VRMUtils.removeUnnecessaryVertices(gltf.scene);
  VRMUtils.removeUnnecessaryJoints(gltf.scene);

  // 4. シーンに追加
  scene.add(vrm.scene);
});
```

### FileReader による読み込み

ユーザーがアップロードしたファイルから読み込む場合:

```javascript
const reader = new FileReader();
reader.onload = (event) => {
  const arrayBuffer = event.target.result;
  loader.parse(arrayBuffer, '', callback);
};
reader.readAsArrayBuffer(file);
```

## ヒューマノイドボーン

VRM はヒューマノイド (人型) モデルのボーン構造を標準化している。

### 必須ボーン

| ボーン名 | 部位 | 説明 |
|---------|------|------|
| `hips` | 腰 | ルートボーン。全体の位置・回転の基点 |
| `spine` | 脊椎 | 上半身の基本回転 |
| `chest` | 胸 | 上半身の補助回転 |
| `head` | 頭 | 頭の回転 |
| `leftUpperArm` | 左上腕 | 肩から肘 |
| `leftLowerArm` | 左前腕 | 肘から手首 |
| `leftHand` | 左手 | 手首 |
| `rightUpperArm` | 右上腕 | (左の鏡像) |
| `rightLowerArm` | 右前腕 | (左の鏡像) |
| `rightHand` | 右手 | (左の鏡像) |
| `leftUpperLeg` | 左太もも | 腰から膝 |
| `leftLowerLeg` | 左すね | 膝から足首 |
| `rightUpperLeg` | 右太もも | (左の鏡像) |
| `rightLowerLeg` | 右すね | (左の鏡像) |

### ボーン操作

```javascript
const humanoid = vrm.humanoid;

// ボーンノードの取得
const bone = humanoid.getNormalizedBoneNode('hips');

// 回転の設定 (ラジアン, Euler 角)
bone.rotation.set(rx, ry, rz);

// 位置の設定 (hips のみ)
bone.position.y = hipsPositionY;  // 現在は常に 0.0 (バウンスなし)
```

### ボーン回転の軸

| 軸 | 正方向 | 例 |
|-----|-------|-----|
| X 軸 | 前方に倒れる | お辞儀 |
| Y 軸 | 左に回転する | 横を向く |
| Z 軸 | 右に傾く | 首をかしげる |

### 14 ボーン x 3 軸 = 42 パラメーター

全ボーンの回転を一括で制御する場合、42 要素のフラット配列 (14 ボーン x XYZ 3 軸) で受け渡すのが効率的。

```javascript
// rotations[i*3], rotations[i*3+1], rotations[i*3+2] が i 番目のボーンの X, Y, Z 回転
for (let i = 0; i < BONE_ORDER.length; i++) {
  const bone = humanoid.getNormalizedBoneNode(BONE_ORDER[i]);
  bone.rotation.set(rotations[i*3], rotations[i*3+1], rotations[i*3+2]);
}
```

## 表情 (Expression)

VRM の表情システムはブレンドシェイプの重みを 0.0-1.0 で制御する。

### 標準表情

| 表情名 | 説明 | 値域 |
|-------|------|------|
| `happy` | 笑顔 | 0.0-1.0 |
| `angry` | 怒り | 0.0-1.0 |
| `sad` | 悲しみ | 0.0-1.0 |
| `relaxed` | リラックス | 0.0-1.0 |
| `surprised` | 驚き | 0.0-1.0 |
| `blink` | 両目まばたき | 0.0-1.0 |
| `blinkLeft` | 左目まばたき | 0.0-1.0 |
| `blinkRight` | 右目まばたき | 0.0-1.0 |
| `aa` | 「あ」の口 (縦に開く) | 0.0-1.0 |
| `ee` | 「い」の口 (横に開く) | 0.0-1.0 |
| `ih` | 「い」の口 (別バリエーション) | 0.0-1.0 |
| `oh` | 「お」の口 | 0.0-1.0 |
| `ou` | 「う」の口 | 0.0-1.0 |

### 表情の操作

```javascript
const expressionManager = vrm.expressionManager;

// 値を設定
expressionManager.setValue('blink', 1.0);     // 目を閉じる
expressionManager.setValue('aa', 0.5);        // 半分口を開ける
```

### 本プロジェクトの表情制御

VRMDancer が毎フレーム以下を計算:

- **blink**: 2-4 秒周期 (`Math.sin` で変動) で 1.0 にスパイク、`delta * 8.0` で約 0.125 秒で減衰
- **mouth_open_vertical** (aa): `sin(@mouth_phase)` による約 6 秒周期、0.0-0.8 の範囲
- **mouth_open_horizontal** (ee): `sin(@mouth_phase + PI/2)` で vertical と 90 度位相差、0.0-0.6 の範囲

```ruby
# vrm_dancer.rb - blink implementation
@blink_timer += delta
if @blink_timer > 3.0 + Math.sin(@time * 0.5) * 1.0  # 2-4 sec interval
  @blink_timer = 0.0
  @blink_value = 1.0  # Trigger
end
@blink_value = [@blink_value - delta * 8.0, 0.0].max  # Decay in ~0.125 sec
```

## スプリングボーン

VRM のスプリングボーンは髪の毛やアクセサリーの物理揺れを自動的に計算する。

### 更新方法

```javascript
// 毎フレーム呼ぶだけでスプリングボーンが自動更新される
vrm.update(deltaTime);
```

`vrm.update()` の呼び出しを忘れると、揺れ物が静止したままになる。

## マテリアル制御

### VRM のマテリアル体系

VRM モデルは以下のマテリアルタイプを使用する:

| タイプ | 特徴 | 照明 |
|-------|------|------|
| MToon | アニメ調のトゥーンシェーダー | 必要 |
| Unlit | 照明なし、テクスチャ色そのまま | 不要 |
| Standard (PBR) | 物理ベースレンダリング | 必要 |

### Emissive による発光制御

VRM モデル全体を音に合わせて光らせるには、全マテリアルの `emissiveIntensity` を一括更新する:

```javascript
// index.html:500-533 (window.updateVRMMaterial)
currentVRM.scene.traverse((node) => {
  if (node.isMesh && node.material) {
    const materials = Array.isArray(node.material) ? node.material : [node.material];
    materials.forEach((mat) => {
      if (mat.emissive && mat.emissiveIntensity !== undefined) {
        mat.emissiveIntensity = emissiveIntensity;
        mat.needsUpdate = true;
      }
    });
  }
});
```

Ruby 側の VRMMaterialController がエネルギーに応じた `emissiveIntensity` を計算 (0.2-1.0 の範囲で線形補間)。

- VRM のマテリアルはローダーのデフォルト設定を尊重 (`emissive` 色は変更しない)
- `emissiveIntensity` のみ毎フレーム動的更新
- `needsUpdate = true` を設定しないとマテリアル変更が反映されない
- 注: `scene.traverse()` は毎フレーム全ノードを走査するためパフォーマンスコストが高い

### VRM のレイヤー構成

VRM モデルはデフォルトのレイヤー 0 に配置される:

- Layer 0: VRM モデル (Bloom の直接対象外)
- Layer 1: BLOOM_LAYER (パーティクル / トーラス用、現在は無効化)
- `camera.layers.enableAll()` で全レイヤーを描画

### VRM に必要な照明

VRM ロード時のみ DirectionalLight と AmbientLight を追加:

```javascript
// index.html:430-434
const dirLight = new THREE.DirectionalLight(0xffffff, 1.0);
dirLight.position.set(1, 2, 1);
scene.add(dirLight);
const ambLight = new THREE.AmbientLight(0x666666);
scene.add(ambLight);
```

VRM なしで起動する場合は照明を追加しない (パーティクル/トーラスは照明不要)。

## VRM アニメーションの実装パターン

### 音楽に合わせたダンスアニメーション

音楽ビジュアライザーでの VRM ダンスは、以下のアプローチが考えられる:

#### 1. マルチフェーズ周期関数ベース (本プロジェクトのアプローチ)

4 つの独立した位相アキュムレータで、体の各部位に異なるリズムを与える:

```ruby
# vrm_dancer.rb - 位相アキュムレータ (MOTION_SPEED = 4.0 で統一制御)
@beat_phase    += delta * 0.8 * MOTION_SPEED    # メイン体幹リズム
@sway_phase    += delta * 0.5 * MOTION_SPEED    # 左右スウェイ
@head_nod_phase += delta * 1.2 * MOTION_SPEED   # 頭の動き
@step_phase    += delta * PI/2 * MOTION_SPEED   # 脚のステップ
```

各ボーンの回転は複数の位相を組み合わせて計算:

```ruby
# 例: hips の回転
rotations.concat([
  Math.sin(@beat_phase * 0.8) * 0.03,   # 前後傾き
  Math.sin(@sway_phase) * 0.12,         # 左右ツイスト
  Math.sin(@beat_phase * 0.6) * 0.04    # 左右リーン
])
```

- 音声データとは独立したリズムで動かし、発光やインパルスで音楽同期を表現
- VRM の動きは常時一定 (音量に関係なく踊り続ける)

#### 2. キーフレームベース

- アニメーションクリップを事前定義
- BPM に合わせて再生速度を調整
- Three.js の `AnimationMixer` を使用

#### 3. IK (Inverse Kinematics) ベース

- 手や足の到達点を指定し、中間ボーンを自動計算
- より自然なポーズ制御が可能
- 計算コストが高い

### スムージングの重要性

ボーン回転を直接設定すると動きが機械的になる。線形補間 (lerp) でスムージングを掛ける:

```ruby
# vrm_dancer.rb:181-188
smoothing_factor = 8.0  # 高い = 追従が速い (慣性小)
smoothed_rotations = []
rotations.each_with_index do |target, i|
  smoothed = MathHelper.lerp(@prev_rotations[i], target, smoothing_factor * delta)
  smoothed_rotations << smoothed
  @prev_rotations[i] = smoothed
end
```

`smoothing_factor * delta` が毎フレームの補間量を決定する。`@prev_rotations` に前フレームの値を保持し、滑らかに追従する。

### 回転値の増幅 (8x)

sin 関数の出力は小さい値 (±0.01-0.15 ラジアン) のため、最終的に 8 倍に増幅して視認可能な動きにする:

```ruby
# vrm_dancer.rb:191
amplified_rotations = smoothed_rotations.map { |r| r * 8.0 }
```

| 生の値 | 増幅後 | 角度換算 |
|--------|--------|---------|
| 0.03 rad | 0.24 rad | ±14 度 |
| 0.12 rad | 0.96 rad | ±55 度 |
| 0.15 rad | 1.20 rad | ±69 度 |

増幅前の値で計算することで精度を保ち、最後に一括増幅する設計。

## 参考リンク

- [VRM 公式サイト](https://vrm.dev/)
- [VRM 仕様 (GitHub)](https://github.com/vrm-c/vrm-specification)
- [@pixiv/three-vrm](https://github.com/pixiv/three-vrm)
- [three-vrm ドキュメント](https://pixiv.github.io/three-vrm/)
- [VRM ヒューマノイドボーン一覧](https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_vrm-1.0/humanoid.md)
