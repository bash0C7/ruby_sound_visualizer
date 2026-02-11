# 3D 基礎ガイド

Three.js を使ったリアルタイム 3D レンダリングの基礎知識。音響ビジュアライザーの開発に必要な概念を解説する。

## 目次

1. [シーングラフ](#シーングラフ)
2. [カメラ](#カメラ)
3. [ジオメトリとメッシュ](#ジオメトリとメッシュ)
4. [パーティクルシステム](#パーティクルシステム)
5. [照明](#照明)
6. [アニメーションループ](#アニメーションループ)
7. [座標系とトランスフォーム](#座標系とトランスフォーム)
8. [パフォーマンス最適化](#パフォーマンス最適化)
9. [参考リンク](#参考リンク)

## シーングラフ

Three.js はシーングラフ (ツリー構造) でオブジェクトを管理する。

```
Scene (ルート)
  ├── Camera (layers.enableAll() で全レイヤー表示)
  ├── Lights
  │   ├── DirectionalLight (VRM 用)
  │   └── AmbientLight (VRM 用)
  ├── Mesh (トーラス: ジオメトリ + MeshStandardMaterial)
  ├── Points (パーティクルシステム: 3000 パーティクル)
  └── VRM Scene (オプション: ユーザーアップロード)
```

- `scene.add(object)` でシーンにオブジェクトを追加
- 子オブジェクトは親の transform (位置・回転・スケール) を継承する
- `scene.traverse(callback)` で全オブジェクトを走査できる

## カメラ

### PerspectiveCamera (透視投影)

人間の目に近い遠近感を持つカメラ。

```javascript
new THREE.PerspectiveCamera(fov, aspect, near, far)
```

| パラメーター | 説明 | 一般的な値 |
|------------|------|----------|
| `fov` | 視野角 (度) | 50-90 |
| `aspect` | アスペクト比 (width/height) | window.innerWidth / window.innerHeight |
| `near` | 最近クリッピング面 | 0.1 |
| `far` | 最遠クリッピング面 | 1000 |

### カメラ操作

```javascript
// 位置設定
camera.position.set(x, y, z);

// 注視点を設定
camera.lookAt(targetVector3);
```

### 球面座標によるカメラ制御

注視点を中心にカメラを球面上で回転させるパターン:

```
x = radius * cos(phi) * sin(theta)
y = radius * sin(phi)
z = radius * cos(phi) * cos(theta)
```

| 変数 | 説明 |
|------|------|
| `theta` | 水平方向の角度 (Y 軸回転) |
| `phi` | 垂直方向の角度 (X 軸回転) |
| `radius` | カメラと注視点の距離 |

- phi を ±90 度付近にクランプすることでジンバルロックを回避する
- radius を固定すれば注視点中心の軌道カメラになる

### レイヤーシステム

Three.js のレイヤーシステムでオブジェクトの描画を選択的に制御できる:

```javascript
// オブジェクトにレイヤーを設定
mesh.layers.set(1);       // レイヤー 1 のみ
mesh.layers.enable(0);    // レイヤー 0 も追加

// カメラで表示するレイヤーを制御
camera.layers.enableAll(); // 全レイヤー表示
camera.layers.set(1);      // レイヤー 1 のみ表示
```

選択的 Bloom (一部のオブジェクトだけ光らせる) などに利用できる。

### 本プロジェクトのレイヤー構成

```javascript
// Layer 0: VRM モデル (デフォルトレイヤー、bloom なし)
// Layer 1: Bloom 対象 (BLOOM_LAYER 定数)
//   ※ 現在はパーティクルとトーラスの layers.set(BLOOM_LAYER) は無効化されている
//   ※ camera.layers.enableAll() で全レイヤーを描画対象にしている
```

## ジオメトリとメッシュ

### Mesh = Geometry + Material

```javascript
const mesh = new THREE.Mesh(geometry, material);
```

### 主要なビルトインジオメトリ

| ジオメトリ | 形状 | パラメーター |
|----------|------|----------|
| `BoxGeometry` | 直方体 | width, height, depth |
| `SphereGeometry` | 球 | radius, widthSegments, heightSegments |
| `TorusGeometry` | ドーナツ | radius, tube, radialSegments, tubularSegments |
| `PlaneGeometry` | 平面 | width, height |
| `CylinderGeometry` | 円柱 | radiusTop, radiusBottom, height |

### TorusGeometry の詳細

```javascript
new THREE.TorusGeometry(radius, tube, radialSegments, tubularSegments)
```

| パラメーター | 説明 |
|------------|------|
| `radius` | トーラスの中心からチューブ中心までの距離 |
| `tube` | チューブの半径 |
| `radialSegments` | 断面の分割数 (多いほど滑らか) |
| `tubularSegments` | チューブに沿った分割数 (多いほど滑らか) |

分割数が多いほど滑らかだが、ポリゴン数が増えて FPS に影響する。

### トランスフォーム操作

```javascript
// スケール (均一)
mesh.scale.set(s, s, s);

// 回転 (ラジアン)
mesh.rotation.set(rx, ry, rz);

// 位置
mesh.position.set(x, y, z);
```

## パーティクルシステム

Three.js では `Points` オブジェクトでパーティクルシステムを実現する。

### 構造

```javascript
// BufferGeometry にパーティクル数 x 3 の Float32Array を設定
const geometry = new THREE.BufferGeometry();
geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));

const material = new THREE.PointsMaterial({ ... });
const particles = new THREE.Points(geometry, material);
```

### BufferAttribute の動的更新

```javascript
// Ruby (または JS) から新しい値を配列にコピー
for (let i = 0; i < newPositions.length; i++) {
  positionAttribute.array[i] = newPositions[i];
}
// 更新フラグを立てる (これがないと GPU に転送されない)
positionAttribute.needsUpdate = true;
```

`needsUpdate = true` の設定を忘れると表示が更新されない点に注意。

### パーティクル数とパフォーマンス

本プロジェクトでは 3000 パーティクルを使用 (`Config::PARTICLE_COUNT = 3000`)。パーティクル数は FPS に直接影響する:

| パーティクル数 | 目安 FPS (一般的な PC) | 用途 |
|-------------|---------------------|------|
| 1,000-3,000 | 60 FPS | 軽量な表現 (本プロジェクト) |
| 5,000-10,000 | 30-60 FPS | リッチな表現 |
| 10,000-50,000 | 15-30 FPS | ヘビーな表現 |

パーティクル数が少ない分、個々のサイズを 2.5 倍に補填して視覚的な密度を維持している。

## 照明

PBR マテリアル (`MeshStandardMaterial`) は照明が必要。`PointsMaterial` は照明の影響を受けない。

### 主要なライトの種類

| ライト | 特性 | 用途 |
|-------|------|------|
| `AmbientLight` | 全方向から均一に照らす | 環境光 (影なし) |
| `DirectionalLight` | 平行光線 (太陽光のように) | メインライト |
| `PointLight` | 点光源 (電球のように) | 局所照明 |
| `SpotLight` | スポットライト (円錐状) | 演出照明 |

### VRM モデルに必要な照明

VRM モデルは PBR マテリアルを使用するため、照明がないと真っ黒になる:

```javascript
// VRM ロード時に照明を追加 (index.html:430-434)
const dirLight = new THREE.DirectionalLight(0xffffff, 1.0);
dirLight.position.set(1, 2, 1);
scene.add(dirLight);

const ambLight = new THREE.AmbientLight(0x666666);
scene.add(ambLight);
```

一方、パーティクル (`PointsMaterial`) やワイヤーフレーム表示は照明不要。照明は VRM ロード時に動的に追加され、VRM なしで起動した場合は追加されない。

## アニメーションループ

### requestAnimationFrame

ブラウザのリフレッシュレートに同期した描画ループ:

```javascript
function animate() {
  requestAnimationFrame(animate);

  // 1. デルタタイム計算
  const now = Date.now();
  const deltaTime = (now - animLastTime) / 1000;
  animLastTime = now;
  window._animDeltaTime = deltaTime;  // Ruby 側から参照可能

  // 2. FFT データ抽出 → Ruby コールバック呼び出し
  if (analyser && window.rubyUpdateVisuals) {
    analyser.getByteFrequencyData(dataArray);
    window.rubyUpdateVisuals(Array.from(dataArray), now);
    // Ruby 側で全計算を行い、JS の update 関数群を呼び出す
  }

  // 3. DOM 更新 (15 フレームごとにスロットリング)
  if (frameCount % 15 === 0) { /* debugInfo, paramInfo 等の表示更新 */ }

  // 4. VRM スプリングボーン更新
  if (currentVRM) currentVRM.update(deltaTime);

  // 5. 描画
  composer.render();  // EffectComposer 経由 (RenderPass → BloomPass → OutputPass)
}
```

### Ruby → JS コールバックによる更新パターン

本プロジェクトでは Ruby 側で全てのビジュアル計算を行い、結果を JS の関数群に渡す:

```
Ruby (WASM)                    JavaScript
  analyze(freq_data)    →
  effect_manager.update →
  JSBridge.update_particles  → window.updateParticles(positions, colors, size, opacity)
  JSBridge.update_geometry   → window.updateGeometry(scale, rotation, emissive, color)
  JSBridge.update_bloom      → window.updateBloom(strength, threshold)
  JSBridge.update_camera     → window.updateCamera(position, shake)
  JSBridge.update_vrm        → window.updateVRM(rotations, hipsY, blink, mouthV, mouthH)
  JSBridge.update_vrm_material → window.updateVRMMaterial(intensity, color)
```

### デルタタイムの重要性

FPS はハードウェアや負荷で変動するため、アニメーションの速度はフレーム数ではなく経過時間 (デルタタイム) に基づくべき:

```
// NG: FPS に依存 (60FPS で速く、30FPS で遅い)
rotation += 0.01;

// OK: 時間に依存 (FPS に関わらず同じ速度)
rotation += speed * deltaTime;
```

## 座標系とトランスフォーム

### Three.js の座標系

Three.js は右手座標系を使用:

```
    Y (上)
    |
    |
    +---- X (右)
   /
  Z (手前)
```

### 回転の単位

Three.js の回転はラジアンを使用:

| 角度 | ラジアン |
|------|---------|
| 90 度 | `Math.PI / 2` ≈ 1.571 |
| 180 度 | `Math.PI` ≈ 3.142 |
| 360 度 | `Math.PI * 2` ≈ 6.283 |
| 10 度 | `Math.PI / 18` ≈ 0.175 |

### ウィンドウリサイズ対応

```javascript
window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  composer.setSize(window.innerWidth, window.innerHeight);
});
```

## パフォーマンス最適化

### レンダリング負荷を下げるポイント

| 項目 | 方法 | 効果 |
|------|------|------|
| ジオメトリの分割数 | segments を減らす | ポリゴン数削減 |
| パーティクル数 | 数を減らす | 頂点処理削減 |
| テクスチャサイズ | 解像度を下げる | GPU メモリ削減 |
| ポストプロセッシング | パス数を減らす | フラグメント処理削減 |
| WebGLRenderer | `antialias: false` | MSAA 無効化 |

### ブラウザ側の対策

- ハードウェアアクセラレーションの有効化 (Chrome/Firefox の設定)
- DevTools コンソールを閉じる (描画負荷軽減)
- 他のタブを閉じる (GPU メモリ節約)

## 参考リンク

- [Three.js 公式ドキュメント](https://threejs.org/docs/)
- [Three.js 基礎 - MDN](https://developer.mozilla.org/en-US/docs/Games/Techniques/3D_on_the_web/Building_up_a_basic_demo_with_Three.js)
- [Three.js PerspectiveCamera](https://threejs.org/docs/#api/en/cameras/PerspectiveCamera)
- [Three.js BufferGeometry](https://threejs.org/docs/#api/en/core/BufferGeometry)
- [Three.js Points](https://threejs.org/docs/#api/en/objects/Points)
- [Three.js Lights](https://threejs.org/docs/#api/en/lights/Light)
