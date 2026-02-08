# Ruby WASM Sound Visualizer 動作確認スキル

このスキルは、Ruby WASM Sound Visualizer の各種機能を自動的に検証します。

## 検証項目

1. **初期化確認**
   - ローカルサーバーの起動確認（http://localhost:8000）
   - ページの読み込み
   - Ruby WASM の初期化（30秒待機）
   - 初期画面のスクリーンショット

2. **キー入力テスト**
   - **0-3キー**: 色モード切り替え（0:Gray, 1:Red, 2:Green, 3:Blue）
   - **4/5キー**: 色相シフト（-5度/+5度）
   - **6/7キー**: 最大輝度調整（-5/+5）
   - **8/9キー**: 最大明度調整（-5/+5）
   - **+/-キー**: 感度調整（±0.05）

3. **デバッグ情報確認**
   - FPS表示
   - Mode表示（色モード）
   - Bass/Mid/High エネルギー値
   - H/S/B（色相/彩度/明度）
   - Volume (dB)
   - BPM推定

4. **エラーチェック**
   - コンソールエラーの確認
   - Ruby初期化エラーの確認

## 実行手順

### 基本モード（デフォルト）

```
/visualizer-test
```

以下の手順を実行：
1. Chrome でタブコンテキストを取得
2. 新しいタブを作成（または既存タブを使用）
3. `http://localhost:8000/index.html?nocache=[timestamp]` に移動
4. 30秒待機（Ruby WASM初期化）
5. スクリーンショットを撮影
6. 色モード切り替えテスト（キー1を押す）
7. 5秒待機
8. スクリーンショットを撮影
9. コンソールエラーをチェック
10. デバッグ情報を確認

### フルモード

```
/visualizer-test --full
```

基本モードに加えて、全てのキー入力パターンをテスト：
1. 基本モードの手順1-6を実行
2. キー0-9, +/- を順番に押して、各状態をスクリーンショット
3. 各キー入力後のデバッグ情報を記録
4. 最終的な動作レポートを生成

### クイックモード

```
/visualizer-test --quick
```

最小限のチェック：
1. ページ読み込み
2. Ruby WASM初期化確認
3. スクリーンショット1枚
4. エラーチェック

## 実装指示

以下のツールを使用して検証を実行してください：

### 1. 初期化フェーズ

```
1. mcp__claude-in-chrome__tabs_context_mcp を呼び出してタブ情報を取得
2. 既存のVisualizerタブがあればそれを使用、なければ tabs_create_mcp で新規作成
3. mcp__claude-in-chrome__navigate でページに移動
   URL: http://localhost:8000/index.html?nocache=[現在のタイムスタンプ]
4. Bash tool で `sleep 30` を実行（Ruby WASM初期化を待機）
5. mcp__claude-in-chrome__computer で screenshot を撮影
6. mcp__claude-in-chrome__read_console_messages でエラーチェック
   pattern: "error|Error|Ruby"
```

### 2. キー入力テストフェーズ

各キーについて以下を実行：

```
1. mcp__claude-in-chrome__computer で key アクションを実行
   例: { action: "key", text: "1", tabId: [tab_id] }
2. Bash tool で `sleep 3` を実行（変更を待機）
3. mcp__claude-in-chrome__computer で screenshot を撮影
4. スクリーンショットから変化を確認（左下のデバッグ情報を確認）
```

**テストするキー一覧：**
- `0`: グレースケールモード
- `1`: 赤モード（240-120度）
- `2`: 緑モード（0-240度）
- `3`: 青モード（120-360度）
- `4`: 色相-5度
- `5`: 色相+5度
- `6`: 輝度-5
- `7`: 輝度+5
- `8`: 明度-5
- `9`: 明度+5
- `-`: 感度-0.05
- `=`: 感度+0.05（+キーの代替）

### 3. デバッグ情報確認フェーズ

```
1. mcp__claude-in-chrome__find で左下のデバッグ情報要素を探す
   query: "FPS counter debug info"
2. スクリーンショットから情報を確認
3. 以下の項目を確認：
   - FPS: 20-30程度が正常
   - Mode: 0:Gray, 1:Hue, 2:Hue, 3:Hue
   - Bass/Mid/High: 0.0%-100.0%
   - H/S/B: 色相(0-360), 彩度(0-100%), 明度(0-100%)
   - Volume: -60dB ~ 0dB
   - BPM: 0 または 40-240
```

### 4. 最終レポート

検証完了後、以下の情報を含むレポートを生成：

```markdown
## Ruby WASM Sound Visualizer 動作確認レポート

**実行日時**: [timestamp]
**テストモード**: [basic/full/quick]

### 初期化
- [✓/✗] ページ読み込み成功
- [✓/✗] Ruby WASM初期化成功（30秒以内）
- [✓/✗] Three.js初期化成功
- [✓/✗] Web Audio API初期化成功

### キー入力テスト
| キー | 機能 | 結果 | 備考 |
|------|------|------|------|
| 0 | グレースケール | ✓/✗ | Mode: 0:Gray確認 |
| 1 | 赤モード | ✓/✗ | Mode: 1:Hue確認 |
| ... | ... | ... | ... |

### デバッグ情報
- FPS: [数値]
- 現在のMode: [Mode文字列]
- Bass/Mid/High: [値]
- Sensitivity: [値]

### エラー
- コンソールエラー数: [数]
- Rubyエラー: [あれば詳細]

### スクリーンショット
- [各スクリーンショットIDのリスト]

### 総評
[全体的な動作状況の評価]
```

## トラブルシューティング

### ローカルサーバーが起動していない場合

```bash
cd /Users/bash/dev/src/github.com/bash0C7/ruby_sound_visualizer
bundle exec ruby -run -ehttpd . -p8000
```

別のターミナルで実行してから、再度スキルを実行してください。

### Ruby WASM初期化が遅い場合

- 初回読み込みはCDNからのダウンロードがあるため40-60秒かかることがあります
- `sleep 30` を `sleep 45` に変更してください

### マイク許可が必要な場合

- ブラウザでマイク許可ダイアログが表示された場合、手動で「許可」をクリックしてください
- その後、スキルを再実行してください

## 期待される動作

### 正常な状態

1. **初期画面**
   - グレースケールのパーティクルとトーラスが表示
   - 左下にデバッグ情報が表示
   - FPS: 20-30程度

2. **キー入力後**
   - 色モード切り替え（0-3）: パーティクルとトーラスの色が変化
   - 色相シフト（4/5）: 色相が±5度ずつ変化
   - 輝度/明度調整（6-9）: パーティクルの明るさが変化
   - 感度調整（+/-）: 音への反応の強さが変化

3. **マイク入力時**
   - 音に反応してパーティクルが爆発
   - トーラスが拡大・回転
   - Bloom効果が強まる
   - デバッグ情報のBass/Mid/High値が変化

### 異常な状態

- **FPS < 10**: パフォーマンス問題
- **Mode表示なし**: Ruby初期化失敗
- **コンソールエラー**: JavaScript/Rubyエラー
- **パーティクルが動かない**: Web Audio API初期化失敗

## 関連ファイル

- プロジェクトディレクトリ: `/Users/bash/dev/src/github.com/bash0C7/ruby_sound_visualizer`
- メインファイル: `index.html`
- ドキュメント: `CLAUDE.md`
- メモリファイル: `/Users/bash/.claude/projects/-Users-bash-dev-src-github-com-bash0C7-ruby-sound-visualizer/memory/MEMORY.md`
