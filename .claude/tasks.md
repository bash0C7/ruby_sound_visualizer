# Ruby WASM Sound Visualizer - Project Tasks

Project task list for tracking progress.

- [x] 普段のmicからの入力のお試しは部屋の環境的に大きな音をたてられない。いざスタジオで試したところずっとbloomがホワイトアウトしており Sensitivity 0.85以下 (スライダーのlowerに近い)にする必要があった。Sensitivity度合いはニュートラル(中央)ポジションになるよう、環境問題はアンプ(+方向)＆アッテネーター(-方向)スライダーを用意する。そして普段はアンプ＆アッテネーター以外の各種パラメーターはデフォルトがニュートラル(中央)にあうように最小値・最大値を調整する。
- [x] 突発的に拍手(hand clap)をすると一気に振り切れてホワイトアウトしてしまう。これを防ぐにはコンプレッサーがいいの？でもシンプルにとどめたいな
- [ ] capture tab, capture videoした場合pref viewには表示されない（背景が黒のまま）、VJ viewには意図通りでてるよ
- [ ] capture tabボタンはトグルのはずだが、押してもボタンが反転の色にならない。どのモードになってるかの把握をしたいため、ONのときは反転。も一度おしたらOFF。
- [ ] capture cameraボタンはトグルのはずだが、押してもボタンが反転の色にならない。どのモードになってるかの把握をしたいため、ONのときは反転。も一度おしたらOFF。
- [ ] pref viewボタンはトグルのはずだが、押してもボタンが反転の色にならない。どのモードになってるかの把握をしたいため、ONのときは反転。も一度おしたらOFF。

## Notes

- All tasks implemented with t-wada style TDD (115 new tests, 100% pass)
- Ruby-first implementation: all logic in Ruby, minimal JS for browser API glue
- Chrome MCP browser testing deferred to local sessions
