# Ruby WASM Sound Visualizer - Project Tasks

プロジェクトの進行状況を追跡するためのタスクリスト。

## 🏗️ 重量級タスク (Major Refactoring)

- [ ] 画面上で Ruby で命令をかけるプロンプトエリアを実装 🌐
  - VJ モード実装
  - 命令 DSL の設計・開発
  - パーティクルやエフェクトの動的制御
  - Plan: [prompt-area.md](plans/prompt-area.md)
  - Depends on: 設定値の一元管理, Ruby クラス構造化

## 📝 Notes

- タスクは上から順に推奨実行順序
- ドキュメント更新 → 重量級タスク という段階的アプローチ
- 重量級タスクは設計フェーズから丁寧に進める
- 各タスク完了後、スクリーンショット + コンソール確認を実施
- 🌐 = Claude Code on Web で実施可能
- 🖥️ = ローカル Claude Code のみ（Chrome MCP + マイク入力が必要）
- Plan ファイルは `.claude/plans/` に格納
