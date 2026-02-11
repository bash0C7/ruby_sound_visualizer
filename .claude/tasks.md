# Ruby WASM Sound Visualizer - Project Tasks

プロジェクトの進行状況を追跡するためのタスクリスト。

## 🚀 軽量タスク (Quick Wins)

- [ ] 画面左下の情報エリアを 4 行にまとめる（文字サイズも小さくする） 🌐
  - Ruby WASM Sound Visualizer 表示は不要
  - 最下段はキーマップを維持
  - その他の情報は行をまとめる
  - Plan: [info-area-compact.md](plans/info-area-compact.md)

- [x] ガイド資料を作成する 🌐
  - シェーダー操作ガイド
  - 3D 基礎ガイド
  - 3D プログラミング・シェーダー用語集
  - VRM 関連ガイド
  - JavaScript-ruby.wasm 連携ガイド
  - ruby.wasm 技術ガイド
  - Plan: [guide-documents.md](plans/guide-documents.md)

- [x] CLAUDE.md をリファクタリングする
  - 2026 年 2 月 Claude Code ベストプラクティスに準拠
  - Skills をプロジェクトローカルで定義
  - 構成を簡潔に整理し、冗長性を削減
  - Table of Contents を追加

## 📊 中量級タスク (Medium)

- [x] 少し音を上げるとトーラスとVRMが画面いっぱいにホワイトアウト状態に飽和する 🖥️
  - ホワイトアウトが続いては画面表示がわからないしパーティクルが目立たなくなるしやりすぎになってしまう。ただし適切な度合いは実際にログや画面表示とマイクからの音入力が必要になるのでローカルのみ

- [ ] パフォーマンスチューニング 🖥️
  - 実際にChromeに接続して、FPS30を目指す

- [ ] 色相の変化を低音・中音・高音の 3 バンドで実装 🌐
  - キーボード 1, 2, 3 で基本色モードを切り替え(ビビッドレッド、ショッキングイエロー、ターコイズブルー)
  - 各モードで基本色を中心に前後70度の色相範囲で3バンドに割り付けて変化させる
  - Plan: [three-band-hue.md](plans/three-band-hue.md)

- [ ] Brightness/Lightness 抑制用の描画レイヤーを追加 🌐
  - 計算式から MAX 値を除外可能にする
  - 設定漏れを防ぐ
  - Plan: [brightness-control-layer.md](plans/brightness-control-layer.md)

- [x] 設定値のデフォルト値を一元管理 🌐
  - 各クラスは振る舞いのみに集中
  - 設定値は共有の定数オブジェクトから参照
  - Plan: [config-centralization.md](plans/config-centralization.md)

- [ ] DevTool コンソールから動的に設定値を変更できるインタフェースを実装 🌐
  - Ruby-JS 相互運用で動的に値を反映
  - デバッグ効率向上
  - Plan: [devtool-interface.md](plans/devtool-interface.md)
  - Depends on: 設定値のデフォルト値を一元管理

## 🏗️ 重量級タスク (Major Refactoring)

- [ ] Ruby のクラスと振る舞いを構造化して、変更の影響を局所化 🌐
  - スパゲッティコード → モジュール化
  - 各クラスの責任を明確化
  - 変更の波及範囲を最小化
  - Plan: [ruby-class-restructure.md](plans/ruby-class-restructure.md)

- [ ] JavaScript のコードを最小化して ruby.wasm に寄せる 🌐
  - ロジック層を Ruby に集約
  - JavaScript は WebGL 操作のみ
  - Ruby-JS 相互運用パターンの標準化
  - Plan: [js-to-ruby-migration.md](plans/js-to-ruby-migration.md)
  - Depends on: Ruby のクラスと振る舞いを構造化

- [ ] ブラウザのコンソールログを Claude Code が読めるように可視化 🌐
  - Chrome MCP ツール連携強化
  - オブザービリティの向上
  - スクリーンショット依存度を削減
  - Plan: [console-log-visibility.md](plans/console-log-visibility.md)
  - Note: コーディングは Web で可能、最終検証はローカル Chrome MCP が必要

- [ ] 画面上で Ruby で命令をかけるプロンプトエリアを実装 🌐
  - VJ モード実装
  - 命令 DSL の設計・開発
  - パーティクルやエフェクトの動的制御
  - Plan: [prompt-area.md](plans/prompt-area.md)
  - Depends on: 設定値の一元管理, Ruby クラス構造化

## 📝 Notes

- タスクは上から順に推奨実行順序
- 軽量タスク → 中量級タスク → 重量級タスク という段階的アプローチ
- 重量級タスクは設計フェーズから丁寧に進める
- 各タスク完了後、スクリーンショット + コンソール確認を実施
- 🌐 = Claude Code on Web で実施可能
- 🖥️ = ローカル Claude Code のみ（Chrome MCP + マイク入力が必要）
- Plan ファイルは `.claude/plans/` に格納
