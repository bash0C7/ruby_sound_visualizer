# Setup & Execution

## Prerequisites

- モダンブラウザ（Chrome, Firefox, Safari, Edge）
- HTTPSまたは localhost での実行（マイク使用のため）
- WebAssembly サポート
- Ruby 3.4.7（Gemfile で指定）

## Installation

### 1. Install Ruby Dependencies

```bash
cd ruby_sound_visualizer
bundle install
```

### 2. Start Local Server

```bash
bundle exec ruby -run -ehttpd . -p8000
```

サーバーが起動したら、ブラウザで以下を開く：

```
http://localhost:8000/index.html
```

## First Run

### Timeline

1. **ページを開く**
   - 「Ruby WASM Sound Visualizer...」ローディング画面が表示

2. **30秒待機（CDN ダウンロード）**
   - CDN から ruby.wasm とライブラリをダウンロード
   - 初回は30秒程度かかる場合あり

3. **マイク許可**
   - ブラウザがマイク使用の許可を求めてくる
   - 「許可」をクリック

4. **自動開始**
   - マイクに音が入ると、自動的にビジュアルが動作開始

## Verification

### Audio Responsiveness

マイクに音が入ると、以下の動作が期待される：

- ✓ パーティクルが音に反応して爆発する
- ✓ トーラスが拡大・回転する
- ✓ パーティクルの色が周波数に応じて変わる
- ✓ 画面全体が発光する（Bloom エフェクト）

### Debug Info

左下のデバッグ情報で以下を確認：

- **FPS**: 20-30程度が正常
- **Mode**: 色モード（0: Gray, 1-3: Hue）
- **Bass/Mid/High**: 周波数帯域のエネルギー値
- **Volume (dB)**: マイク入力レベル

### Automated Testing

簡単なテストは `/visualizer-test` スキルで実行：

```
/visualizer-test --quick
```

詳細なテストは `--full` フラグを使用：

```
/visualizer-test --full
```

## Cache Busting

ブラウザのキャッシュによる問題を避けるため、URL に `?nocache=<random>` を付ける：

```
http://localhost:8000/index.html?nocache=1234567890
```

または、ブラウザの硬いリフレッシュ（Ctrl+Shift+R または Cmd+Shift+R）を使う。

## Troubleshooting

### Ruby WASM が読み込めない

**症状**: "Error: Failed to fetch ruby.wasm"

**解決方法**:
1. ローカルサーバーが起動しているか確認
2. CORS エラーがないか確認（`/troubleshoot` スキルを参照）

### マイクが動作しない

**症状**: 「Permission denied」エラー

**解決方法**:
1. HTTPS または localhost で実行しているか確認
2. ブラウザのマイク許可設定を確認
3. OS レベルでのマイク許可を確認（特に macOS と Windows）

### パフォーマンスが悪い

**症状**: FPS が 10 以下

**解決方法**:
1. [.claude/ARCHITECTURE.md](./ARCHITECTURE.md#performance-optimization) を参照してパーティクル数を減らす
2. ハードウェアアクセラレーションを有効化
3. 他のタブを閉じる（GPU メモリ節約）

### 詳細なトラブルシューティング

```
/troubleshoot
```

## Development Workflow

### Making Changes

1. [index.html](../index.html) を編集
2. ブラウザをリロード（`?nocache=<random>` を使う）
3. Ruby WASM 初期化を待つ（25-30秒）
4. Chrome DevTools でコンソールを確認

### Testing Changes

```
/debug-browser
/visualizer-test --quick
```

### Debugging Protocol

複雑な問題の場合は、[.claude/INVESTIGATION-PROTOCOL.md](./INVESTIGATION-PROTOCOL.md) に従う。

## Related Files

- [index.html](../index.html) - 全コードが含まれる単一ファイル
- [CLAUDE.md](../CLAUDE.md) - プロジェクト指示
- [.claude/ARCHITECTURE.md](./ARCHITECTURE.md) - アーキテクチャ詳細
- [.claude/RUBY-WASM.md](./RUBY-WASM.md) - Ruby WASM 相互運用ガイド
