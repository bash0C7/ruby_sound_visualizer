# Ruby WASM Sound Visualizer - Project Tasks

Project task list for tracking progress.

## Notes

- All tasks implemented with t-wada style TDD (800 tests, 100% pass)
- Ruby-first implementation: all logic in Ruby, minimal JS for browser API glue
- Chrome MCP browser testing deferred to local sessions
- Global variables eliminated: VisualizerApp container class replaces 15 `$` globals


## RuboCop Violation Fixes

Total: 1117 offenses across 73 files (currently suppressed via `.rubocop_todo.yml`).
When fixing each item, remove the corresponding entry from `.rubocop_todo.yml` to lift suppression.

### Safe Autocorrect (--autocorrect)

These can be fixed with `bundle exec rubocop --autocorrect` per cop. Verify tests pass after each.

- [R-1] PENDING: Style/StringLiterals (419) — double quotes to single quotes
  - Largest single cop. `rubocop -a --only Style/StringLiterals`
  - Remove `Style/StringLiterals` section from `.rubocop_todo.yml` after fix
- [R-2] PENDING: Lint/AmbiguousOperatorPrecedence (61) — add parentheses to clarify precedence
  - `rubocop -a --only Lint/AmbiguousOperatorPrecedence`
  - Remove `Lint/AmbiguousOperatorPrecedence` section from `.rubocop_todo.yml` after fix
- [R-3] PENDING: Layout/HashAlignment (43) — hash key alignment
  - `rubocop -a --only Layout/HashAlignment`
  - Remove `Layout/HashAlignment` section from `.rubocop_todo.yml` after fix
- [R-4] PENDING: Layout/EmptyLineAfterGuardClause (42) — blank line after guard clause
  - `rubocop -a --only Layout/EmptyLineAfterGuardClause`
  - Remove `Layout/EmptyLineAfterGuardClause` section from `.rubocop_todo.yml` after fix
- [R-5] PENDING: Layout/ExtraSpacing (29) — remove extra whitespace
  - `rubocop -a --only Layout/ExtraSpacing`
  - Remove `Layout/ExtraSpacing` section from `.rubocop_todo.yml` after fix
- [R-6] PENDING: Layout/ArgumentAlignment (25) — align method arguments
  - `rubocop -a --only Layout/ArgumentAlignment`
  - Remove `Layout/ArgumentAlignment` section from `.rubocop_todo.yml` after fix
- [R-7] PENDING: Style/IfUnlessModifier (20) — convert to one-line modifier form
  - `rubocop -a --only Style/IfUnlessModifier`
  - Remove `Style/IfUnlessModifier` section from `.rubocop_todo.yml` after fix
- [R-8] PENDING: Style/RescueStandardError (20) — explicit StandardError in rescue
  - `rubocop -a --only Style/RescueStandardError`
  - Remove `Style/RescueStandardError` section from `.rubocop_todo.yml` after fix
- [R-9] PENDING: Style/RedundantBegin (15) — remove redundant begin blocks
  - `rubocop -a --only Style/RedundantBegin`
  - Remove `Style/RedundantBegin` section from `.rubocop_todo.yml` after fix
- [R-10] PENDING: Style/NumericLiterals (15) — add underscores to large numbers
  - `rubocop -a --only Style/NumericLiterals`
  - Remove `Style/NumericLiterals` section from `.rubocop_todo.yml` after fix
- [R-11] PENDING: Layout/LineLength (14) — lines over 120 chars
  - `rubocop -a --only Layout/LineLength`
  - Remove `Layout/LineLength` section from `.rubocop_todo.yml` after fix
- [R-12] PENDING: Style/ComparableClamp (13) — use .clamp() instead of min/max chains
  - `rubocop -a --only Style/ComparableClamp`
  - Remove `Style/ComparableClamp` section from `.rubocop_todo.yml` after fix
- [R-13] PENDING: Layout/SpaceAroundOperators (10) — spaces around operators
  - `rubocop -a --only Layout/SpaceAroundOperators`
  - Remove `Layout/SpaceAroundOperators` section from `.rubocop_todo.yml` after fix
- [R-14] PENDING: Style/GuardClause (7) — convert to guard clause
  - `rubocop -a --only Style/GuardClause`
  - Remove `Style/GuardClause` section from `.rubocop_todo.yml` after fix
- [R-15] PENDING: Remaining safe-correctable (misc, ~30 total)
  - TrailingCommaInHashLiteral(7), SpaceInsideHashLiteralBraces(6), NestedTernaryOperator(3),
    TrailingCommaInArrayLiteral(3), UnusedMethodArgument(3), BlockForwarding(3),
    MethodCallWithoutArgsParentheses(3), and 15 single-offense cops
  - `rubocop -a` for all remaining safe cops at once
  - Remove each corresponding section from `.rubocop_todo.yml` after fix

### Unsafe Autocorrect (--autocorrect-all, requires manual review)

- [R-16] PENDING: Style/FrozenStringLiteralComment (72) — add `# frozen_string_literal: true`
  - Decision needed: enable for all files or keep disabled?
  - Currently `.rubocop_todo.yml` has `Enabled: false` for this cop
  - If enabling: `rubocop -A --only Style/FrozenStringLiteralComment` then verify tests
- [R-17] PENDING: Style/NumericPredicate (29) — `x > 0` to `x.positive?`
  - Review each: some may change semantics with nil/non-numeric values
  - Remove `Style/NumericPredicate` section from `.rubocop_todo.yml` after fix
- [R-18] PENDING: Style/MutableConstant (6) — freeze constant values
  - `rubocop -A --only Style/MutableConstant`
  - Remove `Style/MutableConstant` section from `.rubocop_todo.yml` after fix
- [R-19] PENDING: Remaining unsafe-correctable (misc, ~10 total)
  - ZeroLengthPredicate(7), StringConcatenation(2), ComparableBetween(3),
    NonAtomicFileOperation(2), SafeNavigation(1), SlicingWithRange(1), SymbolProc(1)
  - Review and fix individually, remove from `.rubocop_todo.yml` after each

### Manual Fix Required (no autocorrect)

- [R-20] PENDING: Metrics/AbcSize (53) — method complexity too high
  - Refactor complex methods or raise threshold in `.rubocop.yml`
  - Files: audio_analyzer, particle_system, main, visualizer_policy, etc.
  - Remove `Metrics/AbcSize` section from `.rubocop_todo.yml` after fix
- [R-21] PENDING: Naming/VariableNumber (31) — variable naming convention
  - e.g. `color1` vs `color_1`; decide project convention
  - Remove `Naming/VariableNumber` section from `.rubocop_todo.yml` after fix
- [R-22] PENDING: Naming/MethodParameterName (28) — short parameter names
  - e.g. `r, g, b, h, s, v` in math/color methods; consider AllowedNames config
  - Remove `Naming/MethodParameterName` section from `.rubocop_todo.yml` after fix
- [R-23] PENDING: Metrics/CyclomaticComplexity (9) + PerceivedComplexity (5)
  - Complex methods in keyboard_handler, main, particle_system, etc.
  - Remove corresponding sections from `.rubocop_todo.yml` after fix
- [R-24] PENDING: Remaining manual-fix (misc, ~15 total)
  - ClassLength(7), ParameterLists(4), BlockNesting(2), ModuleLength(2),
    DuplicateBranch(2), FloatComparison(1), HashLikeCase(1), PredicatePrefix(1)
  - Fix or configure thresholds per cop, remove from `.rubocop_todo.yml` after each


## SynthPatch Integration Tasks (syn_fm_and_module branch)

### CI Failure (Run 22398472576)

RuboCop violations in newly added test files (not yet in `.rubocop_todo.yml`).

- [S-0] PENDING: Fix RuboCop offenses in SynthPatch tests
  - **`test/test_synth_patch_dsl.rb`**:
    - `Metrics/AbcSize` (too high: 18.11, 19.24, 18.44, 56.01, 30.82 vs threshold 17)
    - `Metrics/CyclomaticComplexity` (10/7) & `PerceivedComplexity` (10/8) for `test_full_dsl_example`
    - `Style/HashConversion`: use `ary.to_h` instead of `Hash[ary]` (Line 123)
  - **`test/test_synth_patch_nodes.rb`**:
    - `Metrics/AbcSize` (20.1, 23.09 vs 17) in `test_set_param_calls_adapter_after_compile`, `test_filter_node_to_h_includes_chain`
  - **`test/test_synth_patch_note.rb`**:
    - `Metrics/AbcSize` (17.03 vs 17) in `test_note_on_includes_adsr_params`
  - **`test/test_vj_pad.rb`**:
    - `Lint/EmptyBlock` (Line 658) in `mock_console.define_singleton_method(:error) { |msg| }`

### 調査結果サマリー（2025-02-24時点）

#### 確認済み実装（index.html 変更済み）

- **Fix 2** ✅: `_pendingSynthPatchSpec` pending rebuild
  `SynthPatch.build()` → `synthPatchBuild(json)` が audioContext なしで呼ばれた場合にキュー、
  `initAudio()` 後に自動リビルド。ログで動作確認済み。

- **Fix 3** ✅: `_synthPatchMasterGainTarget` で Gain スライダーを ADSR peak に反映
  `synthPatchBuild` で初期値読み取り、`synthPatchUpdateParam` で更新、
  `synthPatchNoteOn` の ADSR peak を `_synthPatchMasterGainTarget` で制御。

- **可観測性ログ** ✅: `synthPatchNoteOn`, `synthPatchNoteOff`, `synthPatchUpdateParam` にログ追加済み

- **一時デバッグログ** ⚠️ CLEANUP NEEDED: `init()` に `_initCallCount` カウンタとスタックトレース追加（削除必要）

#### ページリロード問題（未解決・調査中）

**現象**:
- 起動後 9〜90秒の不規則間隔でページが**完全リロード**される
- 毎回 `[JS] init() called, count=1` + `[Ruby] Ruby VM started` が同時に出現
- `_initCallCount = 0` にリセット → スクリプトブロックが再評価されている証拠

**調査済みの否定事項**:
- `browser.script.iife.js` v2.8.1 にリスタート機構なし（one-shot loader）
- `location.reload()` / `location.href=` のコード内呼び出しなし
- WEBrick サーバーに live reload なし
- `history.replaceState` 単独では page reload にならない

**残り仮説（優先度順）**:
1. **Claude in Chrome MCP 拡張機能がリロードを引き起こしている可能性**
   → 拡張機能なしで(`--disable-extensions` など)ページを開いてリロードが起きるか確認
2. **no-cache ヘッダー + Chrome の何らかの動作**
   → 通常の ruby -ehttpd サーバーで試してみる
3. **`history.replaceState` が `?nocache=...` → `?v=1&...` に変わることで何か引き起こす**
   → `scheduleURLUpdate` を一時的に無効化してリロードが止まるか確認

**今のところリロードが起きても Fix 2 でグラフ自動リビルドされるため致命的ではないが、
スライダー値がリセットされる問題はある。**

### 次のアクション

- [S-1] PENDING: 一時デバッグログのクリーンアップ
  `init()` から `_initCallCount` と stack trace を削除
  (`index.html` 2199-2202行付近)

- [S-2] PENDING: ページリロード原因の特定
  上記仮説1から順に検証（拡張機能なし、別サーバー、URL更新無効化）

- [S-3] PENDING: `bundle exec rake test` でテスト全確認
  Fix 2, Fix 3 を含む状態で 949 テスト全通過確認

- [S-4] PENDING: ブラウザ verify（`/verify` スキル）
  S-1, S-3 完了後に実施

- [S-5] PENDING: Controls パネル各スライダー・ボタンの音への反映確認
  sp_co, sp_gain, sp_osc_w, sp_a/d/s/r, sp_ft 全確認
  （serial PicoRuby 入力なしで note_on を手動 VJPad コマンドでテスト）

- [S-6] PENDING: Fix 2 で `synthPatchBuild` 内の `_pendingSynthPatchSpec = null` タイミング
  `initAudio()` が `synthPatchBuild` を呼ぶ前に null クリアしてしまう問題がないか確認

---

## PicoRuby LED Visualizer Tasks (ATOM Matrix)

- [P-8] PENDING: Visual parameter tuning based on hardware feedback
  - `COMPLEMENT_MAX=45` (complement max brightness) — adjust if too dim/bright
  - `COMPLEMENT_MIN=5` (silence floor) — adjust if invisible or too strong
  - If complement looks washed out, try reducing SATURATION for complement rows
- [P-9] PENDING: Consider adding ambient complement animation (optional/future)
  - Currently complement brightness is static in silence (fixed at COMPLEMENT_MIN)
  - Could add slow sine-wave pulse for ambient glow when no audio detected

- [P-12] PENDING [Web/Local]: Button behavior tuning (optional/future)
  - Current: fixed 440Hz per press
  - Alternatives: toggle mute, level-derived frequency, hold-to-sustain
