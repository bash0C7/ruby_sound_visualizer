# Ruby WASM Sound Visualizer - Project Tasks

プロジェクトの進行状況を追跡するためのタスクリスト。

## 🏗️ 重量級タスク (Major Refactoring)

- [x] 画面上で Ruby で命令をかけるプロンプトエリアを実装 🌐
  - VJ モード実装
  - 命令 DSL の設計・開発
  - パーティクルやエフェクトの動的制御
  - Plan: [prompt-area.md](plans/prompt-area.md)
  - Completed: PR #13 merged

## 🎛️ VJ Pad 調整・改善タスク

- [ ] コマンドの種類や発動するエフェクトの調整 🖥️
  - 既存コマンド（burst, flash）のパラメータ調整
  - 新しいエフェクトコマンドの追加検討
  - エフェクトの視覚的インパクトの最適化

- [ ] 音にあわせて発動する爆発的な輝きの度合いの調整 🖥️
  - Bloom 強度の音響連動パラメータ調整
  - パーティクルバーストの音響感度調整
  - 音量・周波数帯域別のエフェクト強度マッピング

## 🎵 音源入力拡張タスク

- [ ] 他のChromeタブからの音声キャプチャ機能 🌐
  - Screen Capture API (`getDisplayMedia`) を使った実装
  - ユーザーがタブ選択して音声を含める設定
  - マイク入力との切り替え UI 実装
  - 技術調査: Chrome Tab Capture API（拡張機能版）も検討

## 📝 Notes

- タスクは上から順に推奨実行順序
- ドキュメント更新 → 重量級タスク という段階的アプローチ
- 重量級タスクは設計フェーズから丁寧に進める
- 各タスク完了後、スクリーンショット + コンソール確認を実施
- 🌐 = Claude Code on Web で実施可能
- 🖥️ = ローカル Claude Code のみ（Chrome MCP + マイク入力が必要）
- Plan ファイルは `.claude/plans/` に格納
