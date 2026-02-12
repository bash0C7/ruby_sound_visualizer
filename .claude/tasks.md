# Ruby WASM Sound Visualizer - Project Tasks

プロジェクトの進行状況を追跡するためのタスクリスト。

## 📋 ドキュメント更新タスク (Documentation)

- [ ] README.md のパーティクル数を修正 🌐
  - 現在「10,000 particles」となっているが、実際は 3,000 particles
  - Line 70: "10,000 particles" → "3,000 particles"

- [ ] README.md の色モード説明を修正 🌐
  - 現在の説明が実装と一致していない
  - 実装: 1=Red(0°), 2=Yellow(60°), 3=Cyan(180°), 各±70°範囲
  - Lines 42-44 の説明を実装に合わせて更新

- [ ] README.md のファイル構造を更新 🌐
  - 以下のファイルが記載漏れしている:
    - visualizer_policy.rb (設定・ポリシー管理)
    - keyboard_handler.rb (キーボード入力処理)
    - debug_formatter.rb (デバッグ情報フォーマット)
    - bpm_estimator.rb (BPM推定)
    - frame_counter.rb (FPS計測)
    - js_bridge.rb (JS-Ruby ブリッジ)
    - math_helper.rb (数学ヘルパー)
    - frequency_mapper.rb (周波数マッピング)

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
