# Implementation Plan: Setup Ruby WASM CI Pipeline

## Overview

Add a GitHub Actions CI workflow that runs on PRs and pushes to main, providing automated test execution and RuboCop linting for the Ruby WASM sound visualizer project.

## Current State

- **Tests**: 800+ tests across 34 test files using test-unit, run via `bundle exec rake test`
- **Linting**: None configured (no RuboCop, no `.rubocop.yml`)
- **CI**: Only `deploy.yml` for GitHub Pages deployment (no test/lint CI)
- **Ruby version**: 3.4.7 (specified in `.ruby-version` and `Gemfile`)
- **Dependencies**: Minimal (webrick, test-unit, rake)

## Key Constraints

- Ruby source files use `require 'js'` (ruby.wasm js gem) in 3 files, but tests mock this via `test_helper.rb` — tests run on standard CRuby
- RuboCop can lint all files; just needs to ignore `JS` module-specific patterns
- No build step needed (browser app, no compilation)

---

## Phase 1: Add RuboCop to Gemfile

**Files modified:**
- `Gemfile` — add `rubocop` gem (dev dependency)

```ruby
gem "rubocop", require: false
```

Then run `bundle install` to update `Gemfile.lock`.

---

## Phase 2: Create `.rubocop.yml` Configuration

**Files created:**
- `.rubocop.yml` — RuboCop configuration tailored to project

Key configuration decisions:
- Target Ruby 3.4
- Exclude `picoruby/` directory (separate project with its own tooling)
- Exclude `vendor/` and `node_modules/` if present
- Disable `Require` cops for `js` gem (not available outside browser)
- Set reasonable line length (120 chars — ruby.wasm code tends to have long JS interop lines)
- Enable only stable cops initially (no pending cops)
- Disable `Style/Documentation` (project uses minimal inline docs, per CLAUDE.md)
- Disable `Metrics/MethodLength` and `Metrics/ClassLength` for test files

---

## Phase 3: Create CI Workflow

**Files created:**
- `.github/workflows/ci.yml` — GitHub Actions CI workflow

### Workflow Design

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - Checkout
      - Setup Ruby 3.4.7 (ruby/setup-ruby@v1)
      - Bundle install (with caching)
      - Run tests: bundle exec rake test

  lint:
    runs-on: ubuntu-latest
    steps:
      - Checkout
      - Setup Ruby 3.4.7 (ruby/setup-ruby@v1)
      - Bundle install (with caching)
      - Run RuboCop: bundle exec rubocop
```

### Design Decisions

1. **Two separate jobs** (test + lint): Run in parallel for faster feedback; a lint failure should not block seeing test results and vice versa
2. **ruby/setup-ruby@v1**: Official Ruby setup action with built-in bundler caching
3. **Ruby 3.4.7**: Match project's `.ruby-version` exactly
4. **No coverage/profiling initially**: Keep scope focused; can add simplecov later

---

## Phase 4: Fix RuboCop Offenses

After adding RuboCop, there will likely be existing offenses. Strategy:

1. Run `bundle exec rubocop` locally to see offense count
2. For offenses that are safe to auto-correct: `bundle exec rubocop -A`
3. For remaining offenses: either fix manually or add targeted exclusions in `.rubocop.yml`
4. Goal: CI passes green on first merge

**Approach**: Use `rubocop --auto-gen-config` to generate `.rubocop_todo.yml` if there are many offenses, then progressively fix them. This lets CI pass immediately while tracking technical debt.

---

## File Modification Summary

**New Files (3):**
1. `.github/workflows/ci.yml` — CI workflow
2. `.rubocop.yml` — RuboCop configuration
3. `.rubocop_todo.yml` — Auto-generated TODO (if needed)

**Modified Files (2):**
1. `Gemfile` — Add rubocop gem
2. `Gemfile.lock` — Updated by bundle install

---

## Success Criteria

- [ ] `bundle exec rake test` passes in CI (all 800+ tests green)
- [ ] `bundle exec rubocop` passes in CI (no offenses or all tracked in TODO)
- [ ] CI runs on PRs to main and pushes to main
- [ ] Two parallel jobs (test + lint) for fast feedback
- [ ] Existing deploy.yml unchanged
