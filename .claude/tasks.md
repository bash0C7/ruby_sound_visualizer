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

- [x] 音にあわせて発動する爆発的な輝きの度合いの調整 🌐
  - Bloom 強度の音響連動パラメータ調整
  - パーティクルバーストの音響感度調整
  - 音量・周波数帯域別のエフェクト強度マッピング
  - 9 mutable params in VisualizerPolicy (bloom, particles, audio)
  - Control Panel UI with sliders (toggle: `p` key)
  - 8 new VJ Pad DSL commands (bbs, bes, bis, pp, pf, fr, vs, id)
  - Completed: 339 tests pass

- [x] コマンドの種類や発動するエフェクトの調整 🌐
  - Plugin system: VJPlugin DSL + EffectDispatcher architecture
  - Existing commands (burst, flash) refactored to plugins
  - 3 new effect plugins: shockwave, strobe, rave
  - EffectDispatcher supports set_param for runtime policy changes
  - `plugins` VJPad command for discoverability
  - Plugin development guide + create-plugin skill
  - Completed: 400 tests pass (merged audio-controls + plugin-system branches)

## 🎵 音源入力拡張タスク

- [x] 他のChromeタブからの音声キャプチャ機能 🌐
  - Screen Capture API (`getDisplayMedia`) を使った実装
  - ユーザーがタブ選択して音声を含める設定
  - マイク入力との切り替え UI 実装
  - 技術調査: Chrome Tab Capture API（拡張機能版）も検討
  - Completed: PR #14 (6 commits, +74 tests, 309 total tests, 100% pass)

## 🧩 コマンド入力・インタラクション拡張タスク

- [ ] コマンド入力機能の plugin 実装として、入力文字列をもとに、画面上に Microsoft Word のワードアートな 90 年代テキストアートを Power Point のアニメーションのようにダサ格好よくエフェクトさせて、一時的に(ある程度の時間)表示する機能を作る 🖥️
  - ドキュメント要点: Local Font Access API はローカルにインストールされたフォントを列挙できる
  - ドキュメント要点: `window.queryLocalFonts()` 初回呼び出しで `"local-fonts"` 権限のユーザープロンプトが出る
  - ドキュメント要点: デスクトップ版 Chrome 103 以降で利用可、モバイル OS では利用不可
  - 技術調査: Local Font Access API の権限の永続性と取り消し方法（サイト情報シート）
  - 実装検討: Three.js テキスト or Canvas テキスト描画のどちらが表現と負荷に適切か比較
  - 演出設計: アニメーションの入退場、残像、グラデーション/アウトラインの定義
  - 参考: https://developer.chrome.com/docs/capabilities/web-apis/local-fonts?hl=ja

- [ ] コマンド入力機能の plugin 実装として、Web Serial API で、指定のシリアルから送信できるようにする。受信した内容はテキストボックス横のエリアに表示 🖥️
  - ドキュメント要点: `navigator.serial.requestPort()` はユーザー操作に反応して呼ぶ必要がある
  - ドキュメント要点: 権限付与済みポートは `navigator.serial.getPorts()` で取得できる
  - ドキュメント要点: `port.open({ baudRate })` でボーレート指定、値を誤ると受信内容が壊れる
  - ドキュメント要点: `port.readable`/`port.writable` は Streams API を使う（`TextDecoderStream` でテキスト化可）
  - ドキュメント要点: `connect`/`disconnect` イベントを監視できる
  - ドキュメント要点: デスクトップ版 Chrome 89 以降で利用可
  - UI 要件: Controls でシリアルデバイスを指定、速度は 38400bps/115200bps から選択
  - 表示設計: 受信ログの表示形式（改行・文字コード・最大行数・クリア操作）
  - 参考: https://developer.chrome.com/docs/capabilities/serial?hl=ja

- [ ] マウスで画面上をドラッグすることで、画面上にペン入力することができる。一定時間でフェードアウトする。色はパーティクルと一緒で、“学園アイドルマスター”風手書きフォントなガールズな文字を手書きで表現できるようにする 🖥️
  - ドキュメント要点: Ink API は OS レベルのコンポジターを使って低遅延なインク描画を目指す
  - ドキュメント要点: エントリーポイントは `navigator.ink`、`requestPresenter()` が `DelegatedInkTrailPresenter` を返す
  - ドキュメント要点: ポインターイベントでインク軌跡を描画する用途向け
  - ドキュメント要点: 実験的機能のためブラウザー互換性の確認が必須
  - 技術調査: Ink API の対応状況と `navigator.ink` 利用条件、フォールバック方針
  - 描画設計: ドラッグ軌跡のスムージング、フェードアウトの時間軸、パーティクル色との同期
  - 参考: https://developer.mozilla.org/ja/docs/Web/API/Ink_API

## 📝 Notes

- タスクは上から順に推奨実行順序
- ドキュメント更新 → 重量級タスク という段階的アプローチ
- 重量級タスクは設計フェーズから丁寧に進める
- 各タスク完了後、スクリーンショット + コンソール確認を実施
- 🌐 = Claude Code on Web で実施可能
- 🖥️ = ローカル Claude Code のみ（Chrome MCP + マイク入力が必要）
- Plan ファイルは `.claude/plans/` に格納
