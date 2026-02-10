# Ruby WASM Sound Visualizer

Browser-based audio visualizer (VJ software) written in Ruby and executed via ruby.wasm.

## Table of Contents

1. [Overview](#overview)
2. [Language Policy](#language-policy)
3. [Development Guidelines](#development-guidelines)
   - [Git Operations](#git-operations)
   - [Implementation Approach](#implementation-approach)
   - [Investigation Protocol](#investigation-protocol)
   - [Browser Testing & Debugging](#browser-testing--debugging)
4. [Technical Specifications](#technical-specifications)
   - [Technology Stack](#technology-stack)
   - [Architecture](#architecture)
   - [File Structure](#file-structure)
5. [Project Skills](#project-skills)
6. [Quick Start](#quick-start)
7. [References](#references)

## Overview

Real-time audio visualizer that analyzes microphone input and generates vivid 3D visual effects using Three.js. Nearly all logic is implemented in Ruby and executed in the browser via @ruby/4.0-wasm-wasi.

## Language Policy

- **Documentation, git comments, code comments**: ALL in English
- **User communication, information provision**: ALL in Japanese Kansai dialect (関西弁)
- **README.md**: ABSOLUTE RULE - ALL in English, no bold emphasis (`**`), no emoji, fact-based language without hyperbole

## Development Guidelines

### Git Operations

- **Use subagent**: Delegate git operations to Task tool subagent
- **Push policy**: Push allowed from Claude Code on web only. Local sessions stop at commit (manual push by humans).
- **Commit message format**: English only, follow conventional commits style

### Implementation Approach

- **t-wada Style TDD**: Develop using Red → Green → Refactor cycle
  - Always start with failing test. Write test before production code.
  - Proceed carefully with test-first approach to avoid breaking existing functionality.
- **Ruby-first implementation**: Implement logic in Ruby as much as possible
- **Scope adherence**: Only modify files specified by user
- **Build/deploy prohibition**: Do not execute unless explicitly instructed
- **Minimal changes**: Targeted changes, not broad refactoring
- **No speculation-based fixes**: Propose investigation instead
- **Critical files**: index.html and Gemfile require explicit user approval before modification

### Investigation Protocol

**CRITICAL: Never fix based on speculation. Always verify facts with debug output before fixing.**

1. Record phenomenon accurately (what is happening)
2. Confirm expected behavior (what should happen)
3. Identify differences (what is different)
4. Formulate hypotheses (max 3, with rationale)
5. Verify with debug output (one at a time)
6. Apply minimal fix
7. Verify with Chrome MCP tools

See [.claude/INVESTIGATION-PROTOCOL.md](.claude/INVESTIGATION-PROTOCOL.md) for detailed workflow.

### Browser Testing & Debugging

**Chrome MCP tools required**: ALWAYS use Chrome MCP tools (`mcp__claude-in-chrome__*`) for browser verification.

Use `/debug-browser` skill for detailed procedures.

## Technical Specifications

### Technology Stack

- **Ruby 3.4.7** (via @ruby/4.0-wasm-wasi 2.8.1)
- **Three.js** (0.160.0) - 3D rendering & post-processing
- **Web Audio API** - Microphone input & frequency analysis

### Architecture

See [.claude/ARCHITECTURE.md](.claude/ARCHITECTURE.md) for detailed architecture documentation.

### File Structure

```
index.html              # Single file containing all code (Ruby + JavaScript + HTML)
.claude/                # Project-specific configuration & documentation
├── ARCHITECTURE.md     # Architecture details
├── INVESTIGATION-PROTOCOL.md  # Investigation protocol
├── RUBY-WASM.md        # Ruby WASM specific knowledge
├── SETUP.md            # Setup & execution instructions
├── tasks.md            # Project task list
└── skills/             # Project-local skills
    ├── debug-browser/  # Browser debugging procedures
    └── troubleshoot/   # Basic troubleshooting
```

## Project Skills

This project defines local skills in `.claude/skills/`. Use skills via Skill tool (e.g., `/debug-browser`).

Available skills:
- **debug-browser**: Detailed browser debugging procedure for ruby.wasm app using Chrome MCP tools
- **troubleshoot**: Basic troubleshooting guide

Skills are project-local and defined within this repository.

## Quick Start

See [.claude/SETUP.md](.claude/SETUP.md) for detailed setup instructions.

```bash
bundle install
bundle exec ruby -run -ehttpd . -p8000
```

Open `http://localhost:8000/index.html` in browser (wait 30 seconds on first load).

## References

- [ruby.wasm Official Documentation](https://ruby.github.io/ruby.wasm/)
- [Three.js Documentation](https://threejs.org/docs/)
- [Web Audio API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [ruby.wasm JavaScript Interop Guide](./.claude/RUBY-WASM.md) - Project-specific knowledge
