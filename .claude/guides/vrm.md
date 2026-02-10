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

// 位置の設定 (hips のみ推奨)
bone.position.y = offsetY;
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

### まばたきの実装パターン

```
1. タイマーを回す (2-4 秒間隔)
2. タイマー到達時に blink = 1.0 に設定
3. 毎フレーム blink -= decay_rate * deltaTime で減衰
4. blink が 0.0 になったら次のタイマー開始
```

瞬きの周期をランダムにすると自然に見える。

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
vrm.scene.traverse((node) => {
  if (node.isMesh && node.material) {
    const materials = Array.isArray(node.material) ? node.material : [node.material];
    materials.forEach((mat) => {
      if (mat.emissiveIntensity !== undefined) {
        mat.emissiveIntensity = newIntensity;
        mat.needsUpdate = true;
      }
    });
  }
});
```

- `emissive` 色を白 (`0xffffff`) にすると、元のテクスチャ色を維持しつつ均一に発光する
- `emissiveIntensity` の範囲: 0.0 (無発光) ~ 任意 (強い発光)
- `needsUpdate = true` を設定しないとマテリアル変更が反映されない

## VRM アニメーションの実装パターン

### 音楽に合わせたダンスアニメーション

音楽ビジュアライザーでの VRM ダンスは、以下のアプローチが考えられる:

#### 1. 周期関数ベース (本プロジェクトのアプローチ)

```
各ボーンの回転 = sin(phase * speed) * amplitude
```

- 複数の位相 (`phase`) を独立に進行させ、体の各部位に異なるリズムを与える
- 振幅 (`amplitude`) で動きの大きさを制御
- 音声データとは独立したリズムで動かし、発光で音楽同期を表現

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

```
実際の回転 = lerp(前フレームの回転, 目標回転, smoothing * deltaTime)
```

`smoothing` 値が大きいほど追従が速い (機敏)、小さいほど追従が遅い (慣性)。

### 回転値の増幅

sin 関数の出力 (-1.0 ~ 1.0) をそのまま使うと動きが小さすぎる場合がある。最終的に増幅係数を掛けて視認性を確保する。

## 参考リンク

- [VRM 公式サイト](https://vrm.dev/)
- [VRM 仕様 (GitHub)](https://github.com/vrm-c/vrm-specification)
- [@pixiv/three-vrm](https://github.com/pixiv/three-vrm)
- [three-vrm ドキュメント](https://pixiv.github.io/three-vrm/)
- [VRM ヒューマノイドボーン一覧](https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_vrm-1.0/humanoid.md)
