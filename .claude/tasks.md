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
