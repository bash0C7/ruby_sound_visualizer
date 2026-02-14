# Ruby WASM Sound Visualizer - Project Tasks

プロジェクトの進行状況を追跡するためのタスクリスト。

## 🐛 既知のバグ (Known Bugs)

- [ ] Perf View ウィンドウが静止して動かない 🖥️
  - **現象**: Perf View ボタンを押して開いたポップアップウィンドウでパーティクルが静止
  - **再現条件**: シングルモニター・マルチモニター両方で再現
  - **調査済み内容**:
    - `?perf=1` タブを直接開くと FPS: 47 で正常動作する
    - `w.focus()` 追加（ポップアップをフォアグラウンドに）しても解決せず
    - Chrome バックグラウンド throttle（`requestAnimationFrame` 1fps制限）の影響が疑われる
    - Ruby WASM 初期化 (`waitForRubyReady`) が詰まっている可能性も残る
  - **未検証の仮説**:
    - ポップアップウィンドウで Ruby WASM の `wasm-wasi` ロードが失敗している
    - `animate()` の `requestAnimationFrame` がバックグラウンドで停止し、初期化完了後も再開されない
  - **次のステップ**: ポップアップ内のコンソールログ・FPS・エラーを Chrome DevTools で直接確認

## External Hardware Integration (Web Serial + PicoRuby)

- [ ] Web Serial -> ATOM Matrix LED meter + low/mid/high analyzer (PicoRuby firmware) 🖥️
  - Goal: send overall level + low/mid/high band values from the browser to ATOM Matrix over USB Serial and render as LEDs.
  - PicoRuby workspace: create `picoruby/` and keep PicoRuby code + PicoRuby AGENTS.md there (task list stays in `.claude/tasks.md`).
  - PicoRuby AGENTS.md: base on upstream CLAUDE.md and add this project’s serial + LED requirements plus ATOM Matrix hardware notes.
    - Create `picoruby/CLAUDE.md`, then add a symlink `picoruby/AGENTS.md` -> `picoruby/CLAUDE.md` to support multi-LLM tooling.
  - Hardware context (from upstream resources):
    - ATOM Matrix uses ESP32-PICO-D4; USB Serial is `ESP32_UART0`.
    - UART example: `UART.new(unit: :ESP32_UART0, baudrate: 115200)` with `bytes_available` + `read(1)`.
    - External UART options include TX/RX 26/32 (Grove) or 22/19 (PortD/J5); button GPIO39.
    - Reference: https://github.com/bash0C7/picoruby-recipes/blob/irq_fukuoka05/src_components/R2P2-ESP32/storage/home/rwc.rb
      - Focus: `pc_uart` setup (`ESP32_UART0`), `bytes_available` + `read(1)` receive loop, and simple command parsing pattern.
  - LED context (from upstream resources):
    - `require 'ws2812'` + `WS2812.new(RMTDriver.new(pin))`.
    - Rendering helpers like `show_hsb_hex` and `flash!` are used in samples.
    - External strip target: `LED_PIN = 33`, `LED_COUNT = 60` (wire like `otma.rb` reference).
    - Reference: https://github.com/bash0C7/picoruby-recipes/blob/irq_fukuoka05/src_components/R2P2-ESP32/storage/home/otma.rb
      - Focus: `require 'ws2812'` usage, `WS2812.new(RMTDriver.new(pin))`, and `show_hsb_hex` rendering call pattern.
  - Serial protocol design: define a stateless frame format (robust to mid-stream disconnects) with explicit start/end markers.
    - Include exact newline behavior (e.g., `\n` or `\r\n`) in the spec and implement on both sides.
    - Decide ASCII vs binary and list byte order and scaling rules for level/low/mid/high (0-255 each).
  - Browser-side implementation: Web Serial UI (requestPort on user action), port selection, baud choices, connect/disconnect handling, and TX log.
  - PicoRuby-side implementation: UART frame parsing and LED buffer updates for low/mid/high visualization.
    - Use HSB; light all LEDs and control brightness by audio magnitude.
    - Update rate: send once per visualizer frame (existing FPS loop); document smoothing policy if used.
  - Verification: human handles build/flash; browser behavior verified with Chrome MCP tools.

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
