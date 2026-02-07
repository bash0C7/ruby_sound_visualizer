# Ruby WASM Sound Visualizer

🎵✨ Rubyで書かれたブラウザベースの音響ビジュアライザー（VJソフト）

マイク入力をリアルタイムで解析し、Three.jsで派手な3D視覚エフェクトを生成します。

![Features](https://img.shields.io/badge/Particles-10k-blue) ![Effects](https://img.shields.io/badge/Effects-Bloom%2FParticles%2FGeometry-green) ![Language](https://img.shields.io/badge/Language-Ruby%2FJavaScript-red)

## クイックスタート

### 1. セットアップ

```bash
# 依存関係をインストール
bundle install
```

### 2. サーバー起動

```bash
# Ruby WEBrick サーバーを起動
bundle exec ruby -run -ehttpd . -p8000
```

### 3. ブラウザで開く

```
http://localhost:8000/index.html
```

### 4. マイク許可

ブラウザがマイク使用の許可を求めてきたら「許可」をクリック

### 5. 音楽を再生

スピーカーやマイクの近くで音楽を再生すると、自動的にビジュアルが反応します！

## 機能

### 視覚エフェクト

- **パーティクルシステム**: 10,000個のパーティクルが音に反応して爆発
- **周波数別色分け**: 低音(赤) / 中音(緑) / 高音(青)の色が動的に変化
- **幾何学変形**: トーラス（ドーナツ形）が音に合わせて拡大縮小・回転
- **発光エフェクト**: Bloom エフェクトで画面全体が輝く

### 技術

- **Ruby 3.4.7** (@ruby/4.0-wasm-wasi) - ロジックはすべてRubyで実装
- **Three.js** - 3D描画とポストエフェクト
- **Web Audio API** - マイク入力と周波数解析
- **単一HTMLファイル** - デプロイが簡単

## ファイル構成

```
ruby_sound_visualizer/
├── README.md           # このファイル
├── CLAUDE.md           # 詳細ドキュメント
├── Gemfile             # Ruby依存関係管理
├── .ruby-version       # Ruby バージョン指定 (3.4.7)
└── index.html          # メインアプリケーション（全コード含む）
```

## トラブルシューティング

### マイクが動作しない

- HTTPS または localhost で実行してください
- ブラウザのマイク許可設定を確認してください

### パフォーマンスが低い

- ブラウザタブを少なくしてください
- ハードウェアアクセラレーションを有効にしてください
- DevTools コンソールを閉じてください

### その他の問題

詳細は [CLAUDE.md](CLAUDE.md) の「トラブルシューティング」セクションをご覧ください

## 開発

### ローカル開発

```bash
# 依存関係をインストール
bundle install

# WEBrick サーバーを起動
bundle exec ruby -run -ehttpd . -p8000

# ブラウザで開く
open http://localhost:8000/index.html
```

### コード修正

`index.html` 内の以下のセクションでコードを編集できます：

- Ruby コード: `<script type="text/ruby">` ブロック内
- JavaScript コード: `<script>` ブロック内

修正後はブラウザをリロードすると変更が反映されます

## 今後の拡張

- God Rays（薄明光線）エフェクト
- プリセットシステム
- MIDI コントローラー対応
- WebVR 対応
- 録画機能

詳細は [CLAUDE.md](CLAUDE.md) の「今後の拡張ポイント」をご覧ください

## ライセンス

MIT License

## リンク

- [Ruby WASM Documentation](https://ruby.github.io/ruby.wasm/)
- [Three.js](https://threejs.org/)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)

---

Made with ❤️ by Rubyists, for VJs 🎵✨
