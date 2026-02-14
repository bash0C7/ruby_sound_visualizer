# Ruby WASM Sound Visualizer 動作確認スキル

このスキルは、Ruby WASM Sound Visualizer の各種機能を自動的に検証します。

## 検証項目

1. **初期化確認**
   - ローカルサーバーの起動確認（http://localhost:8000）
   - ページの読み込み
   - Ruby WASM の初期化（15秒待機） ← Auto-start: Controls パネルが自動表示される
   - 初期画面のスクリーンショット

2. **Controls パネル確認**
   - Color グループ（Hue Wheel, Mode ボタン, Brightness/Saturation スライダー）
   - Master / Bloom / Particles / Rendering / Audio グループ
   - Camera グループ（Distance / H.Rotation / V.Rotation）
   - **Capture グループ**（Overlay Opacity / Video Opacity スライダー）← 今回追加
   - アクションボタン: Load VRM / Capture Tab / **Capture Camera** / **Perf View** / Reset All
   - **Audio ソース**: Mic / Cam Mic / Tab ボタン ← 今回追加

3. **キー入力テスト**
   - **0-3キー**: 色モード切り替え（0:Gray, 1:Red, 2:Green, 3:Blue）
   - **4/5キー**: 色相シフト（-5度/+5度）
   - **6/7キー**: 最大輝度調整（-5/+5）
   - **8/9キー**: 最大明度調整（-5/+5）
   - **+/-キー**: 感度調整（±0.05）
   - **Alt+T**: Tab キャプチャトグル
   - **Alt+C**: カメラキャプチャトグル ← 今回追加

4. **VJ Pad テスト**
   - **バッククォートキー**: プロンプト開閉
   - **色モード変更**: `c 0` (Gray), `c 1` (Red), `c 2` (Green), `c 3` (Blue)
   - **感度調整**: `s 1.5` (感度を1.5に設定)
   - **アクション**: `burst` (パーティクルバースト), `flash` (ブルームフラッシュ)
   - **複数コマンド**: `c 1; s 2.0; flash` (セミコロン区切り)

5. **URL Snapshot テスト** ← 今回追加
   - スライダー操作後に URL パラメータが更新されること
   - `ov=` / `vv=` が URL に含まれること
   - そのURL を開いた時に同じ状態が復元されること

6. **Performance View テスト** ← 今回追加
   - `?perf=1` で開くと Controls パネルが非表示になること
   - VJ Prompt 入力が無効になること

7. **デバッグ情報確認**
   - FPS表示（初期化直後は0、数秒後に20-40程度）
   - Mode表示（色モード）
   - Bass/Mid/High エネルギー値
   - H/S/B（色相/彩度/明度）
   - Volume (dB)
   - BPM推定

8. **エラーチェック**
   - コンソールエラーの確認
   - Ruby初期化エラーの確認
   - VJ Pad コマンド実行エラーの確認

## 実行手順

### 基本モード（デフォルト）

```
/visualizer-test
```

以下の手順を実行：
1. Chrome でタブコンテキストを取得
2. 新しいタブを作成（または既存タブを使用）
3. `http://localhost:8000/index.html?nocache=[timestamp]` に移動
4. `sleep 15` を実行（Ruby WASM初期化）
5. スクリーンショットを撮影（Controls パネルが自動表示されていること確認）
6. キーボードテスト（キー1: Red mode）
7. `sleep 2` を実行
8. スクリーンショットを撮影
9. VJ Pad テスト（下記「VJ Pad テスト実装」参照）
10. URL Snapshot テスト
11. Performance View テスト
12. コンソールエラーをチェック
13. レポート生成

### フルモード

```
/visualizer-test --full
```

基本モードに加えて、全てのキー入力パターンをテスト：
1. 基本モードの手順1-8を実行
2. キー0-9, +/- を順番に押して、各状態をスクリーンショット
3. Controls パネルの全スライダー操作確認
4. 各キー入力後のデバッグ情報を記録
5. 最終的な動作レポートを生成

### クイックモード

```
/visualizer-test --quick
```

最小限のチェック：
1. ページ読み込み
2. Ruby WASM初期化確認（Controls パネル表示確認）
3. スクリーンショット1枚
4. エラーチェック

## 実装指示

### 1. 初期化フェーズ

```
1. mcp__claude-in-chrome__tabs_context_mcp を呼び出してタブ情報を取得
2. 既存のVisualizerタブがあればそれを使用、なければ tabs_create_mcp で新規作成
3. mcp__claude-in-chrome__navigate でページに移動
   URL: http://localhost:8000/index.html?nocache=[現在のタイムスタンプ]
4. Bash tool で `sleep 15` を実行（Ruby WASM初期化を待機）
5. mcp__claude-in-chrome__computer で screenshot を撮影
   → Controls パネルが表示されていること確認（"Start without VRM" ボタンは存在しない）
6. mcp__claude-in-chrome__read_console_messages でエラーチェック
   pattern: "error|Error|Ruby"
```

### 2. VJ Pad テスト実装（CRITICAL: 競合回避）

**重要**: `type` アクション前に必ず入力フィールドをクリアすること。
`key Return` のあと JavaScript の clearが間に合わないため、`rubyExecPrompt` を直接呼ぶか、
`triple_click` でフィールドを選択してから `type` することで回避できる。

#### 推奨: JavaScript 直接呼び出し方式（信頼性が高い）

```javascript
mcp__claude-in-chrome__javascript_tool(
  text: `
    const results = {};
    const tests = [
      ['c 3', 'color: blue'],
      ['burst', 'burst!'],
      ['flash', 'flash!'],
      ['s 1.5', 'sens: 1.5'],
      ['c 2; burst', 'burst!'],
      ['c 1', 'color: red'],
    ];
    for (const [cmd, expected] of tests) {
      try {
        const r = String(window.rubyExecPrompt(cmd));
        results[cmd] = { result: r, pass: r === expected };
      } catch(e) { results[cmd] = { result: 'ERR: ' + e.message, pass: false }; }
    }
    JSON.stringify(results)
  `
)
```

#### フォールバック: キーボード入力方式（UX確認用）

バッククォートでプロンプト開閉のUX確認のみに使用すること：

```
1. mcp__claude-in-chrome__computer で key アクション: "`"
2. sleep 1
3. mcp__claude-in-chrome__find で "VJ prompt input" を探す
4. mcp__claude-in-chrome__computer で triple_click（全選択）
5. mcp__claude-in-chrome__computer で type でコマンド入力
6. sleep 1（フィールドへの反映待ち）
7. mcp__claude-in-chrome__computer で key: "Return"
8. sleep 1（Ruby 実行完了待ち）
9. mcp__claude-in-chrome__javascript_tool で結果確認
   text: "document.getElementById('vjPromptResult').textContent"
```

**テストするコマンド例:**
- `c 1`: 赤モードに変更（結果: "color: red"）
- `s 1.5`: 感度を1.5に設定（結果: "sens: 1.5"）
- `burst`: パーティクルバースト（結果: "burst!"）
- `flash`: ブルームフラッシュ（結果: "flash!"）
- `c 2; burst`: 複数コマンド実行（結果: "burst!"）

### 3. Controls パネルテスト

```javascript
// Capture スライダー確認
mcp__claude-in-chrome__javascript_tool(
  text: `JSON.stringify({
    capOverlayOpacity: window.capOverlayOpacity,
    capVideoOpacity: window.capVideoOpacity,
    overlaySlider: document.getElementById('cpSlider_cap_overlay_opacity')?.value,
    videoSlider: document.getElementById('cpSlider_cap_video_opacity')?.value,
  })`
)
// ※ capOverlayOpacity は let スコープなのでグローバルからは undefined。スライダー値で確認
```

スライダー操作テスト:
```
1. mcp__claude-in-chrome__find で "Overlay Opacity slider" を探す
2. mcp__claude-in-chrome__form_input で値を 0.2 に設定
3. sleep 1
4. URL に &ov=0.20 が含まれることを確認（tab URL から）
```

### 4. URL Snapshot テスト

```javascript
// 1. Overlay Opacity を変更
mcp__claude-in-chrome__form_input(ref: [overlay_slider_ref], value: 0.3)
// sleep 1
// 2. URLに ov=0.30 が含まれることを確認
mcp__claude-in-chrome__javascript_tool(
  text: "window.location.search.includes('ov=0.30')"
)
// 3. URL を再ロードして値が復元されることを確認
```

### 5. Performance View テスト

Performance View は `?perf=1` URLで起動する独立ウィンドウ。BroadcastChannel で状態を受信しシーンを更新する。

#### 5-a. 単体起動テスト（Perf View ウィンドウの動作確認）

```
1. mcp__claude-in-chrome__tabs_create_mcp で新規タブ作成
2. mcp__claude-in-chrome__navigate(url: "http://localhost:8000/index.html?perf=1&nocache=[ts]")
3. Bash で sleep 15（Ruby WASM初期化）
4. screenshot を撮影
5. 以下を確認:
   a) Controls パネルが非表示
      javascript: "document.getElementById('controlPanel').style.display"
      期待値: "none"
   b) Ruby WASM が動作している（rubyUpdateVisuals が呼ばれている）
      javascript: "typeof window.rubyUpdateVisuals"
      期待値: "function"
   c) パーティクル / シーンが動いている（FPS表示が 0 以外）
      javascript: "document.getElementById('fpsCounter').textContent"
      期待値: 数値文字列（"0 fps" 以外）
   d) BroadcastChannel receiver が起動している
      javascript: "typeof window._perfChannel" （注: let スコープなので直接アクセス不可）
      → コンソールで "[JS] BroadcastChannel receiver started" ログを確認
      read_console_messages(pattern: "BroadcastChannel receiver")
```

#### 5-b. Perf View ボタンテスト（メインウィンドウから起動）

```
1. メインウィンドウに戻る（元のタブ）
2. Controls パネルに "Perf View" ボタンがあることを確認
   javascript: "document.getElementById('cpPerfViewBtn')?.textContent"
   期待値: "Perf View"
3. Perf View ボタンをクリック（popup ブロックに注意）
   ※ popup ブロックの場合はブラウザのポップアップ許可が必要
4. sleep 2 後、BroadcastChannel 送信が行われていることを確認
   read_console_messages(pattern: "Perf view window opened")
```

#### 5-c. BroadcastChannel 同期テスト

```
1. メインウィンドウでスライダー操作（例: Camera Distance 変更）
2. scheduleURLUpdate が呼ばれ broadcastState() も呼ばれる
3. Perf View ウィンドウでカメラ位置が変わることを確認
   （タブを切り替えてスクリーンショット比較）
```

### 6. デバッグ情報確認フェーズ

```
1. スクリーンショットの左下テキストを確認
2. 以下の項目を確認：
   - FPS: 初期化直後は0、数秒後に20-40程度が正常
   - Mode: 0:Gray, 1:Hue, 2:Hue, 3:Hue
   - Bass/Mid/High: 0.0%-100.0%
   - H/S/B: 色相(0-360), 彩度(0-100%), 明度(0-100%)
   - Volume: -60dB ~ 0dB
   - BPM: 0 または 40-240
```

### 7. 最終レポート

検証完了後、以下の情報を含むレポートを生成：

```markdown
## Ruby WASM Sound Visualizer 動作確認レポート

**実行日時**: [timestamp]
**テストモード**: [basic/full/quick]

### 初期化
- [✓/✗] ページ読み込み成功
- [✓/✗] Ruby WASM 初期化成功（Auto-start、Controls パネル自動表示）
- [✓/✗] Three.js 初期化成功
- [✓/✗] Web Audio API 初期化成功

### Controls パネル
- [✓/✗] Capture グループ表示（Overlay Opacity / Video Opacity）
- [✓/✗] Capture Camera / Perf View ボタン表示
- [✓/✗] Audio Source ボタン（Mic / Cam Mic / Tab）表示

### キー入力テスト
| キー | 機能 | 結果 | 備考 |
|------|------|------|------|
| 1 | 赤モード | ✓/✗ | Mode: 1:Hue確認 |
| ... | ... | ... | ... |

### VJ Pad テスト
| コマンド | 期待値 | 実際の結果 | 結果 | 備考 |
|----------|--------|------------|------|------|
| ` | プロンプト開閉 | - | ✓/✗ | プロンプトが表示 |
| c 3 | color: blue | [実際] | ✓/✗ | |
| burst | burst! | [実際] | ✓/✗ | |
| flash | flash! | [実際] | ✓/✗ | |
| s 1.5 | sens: 1.5 | [実際] | ✓/✗ | |
| c 2; burst | burst! | [実際] | ✓/✗ | セミコロン複数コマンド |

### URL Snapshot テスト
- [✓/✗] スライダー操作で URL に ov/vv パラメータが追加される
- [✓/✗] URL 復元で Capture スライダーが正しく復元される

### Performance View テスト
- [✓/✗] "Perf View" ボタンが Controls に表示される
- [✓/✗] ?perf=1 で Controls パネルが非表示
- [✓/✗] ?perf=1 で VJ Prompt 入力が無効
- [✓/✗] ?perf=1 で Ruby WASM が動作（rubyUpdateVisuals が呼ばれる）
- [✓/✗] ?perf=1 でパーティクル/シーンが動いている（FPS > 0）
- [✓/✗] BroadcastChannel receiver が起動している

### デバッグ情報
- FPS: [数値]（初期化直後は0、数秒後に20-40程度）
- 現在のMode: [Mode文字列]
- Bass/Mid/High: [値]
- Sensitivity: [値]

### エラー
- コンソールエラー数（アプリ本体）: [数]
  ※ テスト手順の競合由来エラー（burstc, bursts 等）は除外
- Ruby エラー: [あれば詳細]
- VJ Pad エラー: [あれば詳細]

### スクリーンショット
- [各スクリーンショットIDのリスト]

### 総評
[全体的な動作状況の評価]
- 既存機能のデグレードチェック: [✓/✗]
- VJ Pad 機能の動作確認: [✓/✗]
- URL Snapshot 機能: [✓/✗]
- Performance View 機能: [✓/✗]
```

## トラブルシューティング

### ローカルサーバーが起動していない場合

```bash
cd /Users/bash/dev/src/github.com/bash0C7/ruby_sound_visualizer
bundle exec rake server:start
```

### Ruby WASM初期化が遅い場合

- 通常は15秒以内に完了。初回読み込みはCDNダウンロードがあるため遅くなる場合あり
- `sleep 15` を `sleep 30` に変更してください

### マイク許可が必要な場合

- ブラウザでマイク許可ダイアログが表示された場合、手動で「許可」をクリックしてください
- その後、スキルを再実行してください

### VJ Pad type 競合エラー（burstc, bursts 等）

**原因**: `key Return` のあと JavaScript の `vjInput.value = ''` が実行される前に `type` アクションが走り、前のコマンドテキストに追記されてしまう。

**解決策**: `rubyExecPrompt` を JavaScript ツールで直接呼ぶ方式に切り替える（上記「推奨方式」参照）。

## 期待される動作

### 正常な状態

1. **初期画面**
   - グレースケールのパーティクルとトーラスが表示
   - Controls パネルが自動表示（右側）
   - 左下にデバッグ情報が表示
   - FPS: 初期化直後は0、数秒後に20-40程度

2. **Controls パネル**
   - Capture グループに Overlay Opacity (0.50) / Video Opacity (1.00) スライダー
   - Load VRM / Capture Tab / Capture Camera / Multi-Monitor / Reset All ボタン
   - Audio: Mic / Cam Mic / Tab ボタン（Mic がデフォルト active）

3. **キー入力後**
   - 色モード切り替え（0-3）: パーティクルとトーラスの色が変化
   - 色相シフト（4/5）: 色相が±5度ずつ変化
   - 輝度/明度調整（6-9）: パーティクルの明るさが変化
   - 感度調整（+/-）: 音への反応の強さが変化

4. **VJ Pad 操作後**
   - **バッククォートキー**: 画面下部にプロンプトが表示
   - **コマンド実行**: 入力欄の右に実行結果が表示（例: "color: blue", "burst!", "flash!"）
   - **色モード変更（c 0-3）**: パーティクルの色が即座に変化
   - **burst コマンド**: パーティクルが画面全体に大爆発
   - **flash コマンド**: 画面が真っ白にフラッシュ
   - **複数コマンド**: セミコロン区切りで複数コマンドが順次実行
   - **エラー時**: 入力欄の右に赤文字で "ERR: ..." と表示

5. **URL Snapshot**
   - スライダー操作後0.5秒でURLが更新される
   - URL形式: `?v=1&hue=...&ov=0.50&vv=1.00`
   - URL読み込みで全パラメータが復元される

6. **Performance View (`?perf=1`)**
   - Controls パネルが非表示
   - VJ Prompt の入力が無効（display:none）
   - ビジュアルのみ全画面表示
   - BroadcastChannel で状態受信（Multi-Monitor 連携）

### 異常な状態

- **FPS < 10**: パフォーマンス問題（初期化直後の FPS: 0 は正常）
- **Mode表示なし**: Ruby初期化失敗
- **コンソールエラー（アプリ本体）**: JavaScript/Rubyエラー
- **パーティクルが動かない**: Web Audio API初期化失敗
- **VJ Pad プロンプトが開かない**: バッククォートキーの処理に問題
- **VJ Pad コマンドエラー**: 構文エラーまたは未定義コマンド（赤文字で表示）
- **Capture スライダーが URL に反映されない**: scheduleURLUpdate の問題
- **?perf=1 で Controls が表示される**: IS_PERF_VIEW 判定の問題

## 関連ファイル

- プロジェクトディレクトリ: `/Users/bash/dev/src/github.com/bash0C7/ruby_sound_visualizer`
- メインファイル: `index.html`
- ドキュメント: `CLAUDE.md`
- メモリファイル: `/Users/bash/.claude/projects/-Users-bash-dev-src-github-com-bash0C7-ruby-sound-visualizer/memory/MEMORY.md`
