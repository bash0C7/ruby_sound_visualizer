# Ruby WASM Sound Visualizer

ブラウザで動作する、Rubyで書かれた音響ビジュアライザー（VJソフトウェア）

## Language Policy

- **Documentation, git comments, code comments**: ALL in English
- **User communication, information provision**: ALL in Japanese Kansai dialect (関西弁)
- **README.md**: ABSOLUTE RULE - ALL in English, no bold emphasis (`**`), no emoji, fact-based language without hyperbole

## git操作

- **subagent を使うこと**: git 操作は Task tool を使って subagent に委譲する
- **push は厳格に禁止**: リモートへの push は人間が行う。Claude は commit までで止める
- **Commit message format**: English only, follow conventional commits style

## 実装の注意

- **t-wada Style TDD**: Red → Green → Refactor サイクルで開発
  - 必ず failing test から始める。production code より先に test を書く
  - 既存の処理を壊さないよう慎重にテストファーストで進める
- **ruby.wasm コードを主体にする**: ロジックは可能な限り Ruby で実装

## ブラウザテスト・デバッグ

**Chrome MCP ツール必須**: ブラウザでの動作確認には Chrome MCP ツール（`mcp__claude-in-chrome__*`）を**常に使用**すること

詳細な手順は `/debug-browser` スキルを参照。

## 調査プロトコル

**CRITICAL: 憶測で修正せず、必ずデバッグ出力で事実を確認してから修正すること**

1. 現象を正確に記録する（何が起きているか）
2. 期待される動作を確認する（何が起きるべきか）
3. 差分を特定する（何が違うのか）
4. 仮説を立てる（最大3つ、根拠を明記）
5. デバッグ出力で検証する（一つずつ確認）
6. 最小限の修正を実施する
7. Chrome MCP ツールで検証する

詳細なワークフローは [.claude/INVESTIGATION-PROTOCOL.md](.claude/INVESTIGATION-PROTOCOL.md) を参照。

## アプローチ制約

- **ファイル修正スコープ厳守**: ユーザーが指定したファイルのみを修正
- **ビルド/デプロイ禁止**: 明示的に指示されない限り実行しない
- **最小限の変更**: 広範なリファクタリングではなく、ターゲットを絞った変更
- **推測ベースの修正禁止**: 調査を提案する
- **index.html と Gemfile は慎重に**: 変更時は必ずユーザーの明示的な承認を得る

## 概要

マイク入力をリアルタイムで解析し、Three.jsで派手な3D視覚エフェクトを生成します。
ロジックのほぼ全てをRubyで実装し、@ruby/4.0-wasm-wasiによってブラウザで実行されます。

## 技術スタック

- **Ruby 3.4.7** (via @ruby/4.0-wasm-wasi 2.8.1)
- **Three.js** (0.160.0) - 3D rendering & post-processing
- **Web Audio API** - マイク入力 & 周波数解析

詳細なアーキテクチャは [.claude/ARCHITECTURE.md](.claude/ARCHITECTURE.md) を参照。

## ファイル構成

[index.html](./index.html) - 全コードを含む単一ファイル（Ruby + JavaScript + HTML）

[.claude/](./.claude/) - プロジェクト固有の設定・ドキュメント
- [ARCHITECTURE.md](./.claude/ARCHITECTURE.md) - アーキテクチャ詳細
- [INVESTIGATION-PROTOCOL.md](./.claude/INVESTIGATION-PROTOCOL.md) - 調査プロトコル
- [RUBY-WASM.md](./.claude/RUBY-WASM.md) - Ruby WASM 固有の知見
- [SETUP.md](./.claude/SETUP.md) - セットアップ・実行方法
- [skills/](./.claude/skills/) - プロジェクト固有スキル

## セットアップ

セットアップと実行方法は [.claude/SETUP.md](./.claude/SETUP.md) を参照。

```bash
bundle install
bundle exec ruby -run -ehttpd . -p8000
```

ブラウザで `http://localhost:8000/index.html` を開く（初回は30秒待機）

## トラブルシューティング

基本的なトラブルシューティングは `/troubleshoot` スキルを参照。

## 参考資料

- [ruby.wasm Official Documentation](https://ruby.github.io/ruby.wasm/)
- [Three.js Documentation](https://threejs.org/docs/)
- [Web Audio API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [ruby.wasm JavaScript Interop Guide](./.claude/RUBY-WASM.md) - プロジェクト固有の知見
