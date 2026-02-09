# Documentation Index

Quick reference to all documentation in this repository.

## For Developers (Start Here)

**New to this codebase?** Read these in order:

1. **[README.md](README.md)** - Project overview, installation, quick start
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design decisions
3. **[.claude/CLAUDE.md](.claude/CLAUDE.md)** - Development guidelines, common pitfalls, workflow
4. **[test/completion-status.md](test/completion-status.md)** - Spec-by-spec test coverage matrix

## Core Documentation

### Architecture & Design

- **[ARCHITECTURE.md](ARCHITECTURE.md)** ⭐ - System architecture
  - Component structure
  - Dependency injection patterns
  - WebSocket abstraction
  - Connection state machine
  - Design decisions and rationale

### Test Coverage

- **[test/completion-status.md](test/completion-status.md)** ⭐ - Spec coverage matrix
  - Spec-by-spec test tracking (RSA, RSC, RTN, RTL, etc.)
  - Dart test and UTS spec cross-references
  - Summary counts by area

### Testing Infrastructure

- **[test/helpers/MOCK_HTTP_CLIENT.md](test/helpers/MOCK_HTTP_CLIENT.md)** - Mock API reference
  - Handler pattern
  - Awaitable pattern
  - Request capture
  - Error simulation

### Development Guidelines

- **[.claude/CLAUDE.md](.claude/CLAUDE.md)** - Context for AI assistants and developers
  - Architecture principles
  - Testing patterns
  - Common pitfalls (with examples)
  - File structure reference
  - What to preserve vs. change

## Test Specifications

Test specs follow [Universal Test Specification (UTS)](https://github.com/ably/ably-common/tree/main/test-resources) format and live in `../uts/test/`:

**Key realtime test specs:**
- `../uts/test/realtime/integration/connection_lifecycle_test.md`
- `../uts/test/realtime/unit/connection/connection_open_failures_test.md`
- `../uts/test/realtime/unit/connection/connection_failures_test.md`

## External Resources

- **[Ably Client Library Specification](https://sdk.ably.com/builds/ably/specification/main/features/)** - Official spec
- **[ably-flutter](https://github.com/ably/ably-flutter)** - Flutter wrapper using ably-dart

## Quick Reference by Audience

### New Contributors
1. README.md
2. ARCHITECTURE.md
3. .claude/CLAUDE.md

### Test Writers
1. test/helpers/MOCK_HTTP_CLIENT.md
2. test/completion-status.md
3. .claude/CLAUDE.md (testing section)

### Project Managers
1. README.md
2. test/completion-status.md

### AI Assistants
1. .claude/CLAUDE.md (primary context)
2. ARCHITECTURE.md
3. test/completion-status.md

## Document Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| README.md | Current | 2026-02-06 |
| ARCHITECTURE.md | Current | 2026-02-02 |
| .claude/CLAUDE.md | Current | 2026-02-02 |
| test/completion-status.md | Current | 2026-02-06 |
| test/helpers/MOCK_HTTP_CLIENT.md | Current | Reference |
