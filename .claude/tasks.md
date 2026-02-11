# Ruby WASM Sound Visualizer - Project Tasks

プロジェクトの進行状況を追跡するためのタスクリスト。

## 📊 中量級タスク (Medium)

- [ ] BPMの判定が実測FPSと乖離する
  - P2 Badge Use measured FPS below 30 when estimating BPM
    - This call clamps fps to at least 30 before passing it into BPMEstimator, so any real frame rate in the 10–29 FPS range is treated as 30 FPS and BPM is systematically overestimated on slower devices (for example, a true 120 BPM stream at ~15 FPS will be reported near double). BPMEstimator already contains its own low-FPS guard (fps < 10), so this pre-clamp removes valid signal and regresses accuracy under load.
  - Plan: [bpm-fps-divergence.md](plans/bpm-fps-divergence.md)

- [ ] パフォーマンスチューニング 🖥️
  - 実際にChromeに接続して、FPS30を目指す
  - Plan: [performance-tuning.md](plans/performance-tuning.md)

- [ ] 色相の変化を低音・中音・高音の 3 バンドで実装 🌐
  - キーボード 1, 2, 3 で基本色モードを切り替え(ビビッドレッド、ショッキングイエロー、ターコイズブルー)
  - 各モードで基本色を中心に前後70度の色相範囲で3バンドに割り付けて変化させる
  - Plan: [three-band-hue.md](plans/three-band-hue.md)

- [ ] Brightness/Lightness 抑制用の描画レイヤーを追加 🌐
  - 計算式から MAX 値を除外可能にする
  - 設定漏れを防ぐ
  - Plan: [brightness-control-layer.md](plans/brightness-control-layer.md)

## 🏗️ 重量級タスク (Major Refactoring)

- [ ] 画面上で Ruby で命令をかけるプロンプトエリアを実装 🌐
  - VJ モード実装
  - 命令 DSL の設計・開発
  - パーティクルやエフェクトの動的制御
  - Plan: [prompt-area.md](plans/prompt-area.md)
  - Depends on: 設定値の一元管理, Ruby クラス構造化

## 📝 Notes

- タスクは上から順に推奨実行順序
- 中量級タスク → 重量級タスク という段階的アプローチ
- 重量級タスクは設計フェーズから丁寧に進める
- 各タスク完了後、スクリーンショット + コンソール確認を実施
- 🌐 = Claude Code on Web で実施可能
- 🖥️ = ローカル Claude Code のみ（Chrome MCP + マイク入力が必要）
- Plan ファイルは `.claude/plans/` に格納
