# Documentation Index

Quick reference to all documentation in this repository.

## For Developers (Start Here)

**New to this codebase?** Read these in order:

1. **[README.md](README.md)** - Project overview, installation, quick start
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design decisions
3. **[.claude/CLAUDE.md](.claude/CLAUDE.md)** - Development guidelines, common pitfalls, workflow
4. **[REALTIME_IMPLEMENTATION_COMPLETE.md](REALTIME_IMPLEMENTATION_COMPLETE.md)** - Current implementation status

## Core Documentation

### Architecture & Design

- **[ARCHITECTURE.md](ARCHITECTURE.md)** ⭐ - System architecture
  - Component structure
  - Dependency injection patterns
  - WebSocket abstraction
  - Connection state machine
  - Design decisions and rationale

### Implementation Status

- **[REALTIME_IMPLEMENTATION_COMPLETE.md](REALTIME_IMPLEMENTATION_COMPLETE.md)** ⭐ - Implementation status
  - What was built
  - Core components
  - Test coverage
  - Production features

- **[TEST_IMPLEMENTATION_STATUS.md](TEST_IMPLEMENTATION_STATUS.md)** - Test tracking
  - Test files implemented
  - Spec coverage breakdown
  - Test patterns
  - Running tests

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
2. TEST_IMPLEMENTATION_STATUS.md
3. .claude/CLAUDE.md (testing section)

### Project Managers
1. README.md
2. REALTIME_IMPLEMENTATION_COMPLETE.md
3. TEST_IMPLEMENTATION_STATUS.md

### AI Assistants
1. .claude/CLAUDE.md (primary context)
2. ARCHITECTURE.md
3. REALTIME_IMPLEMENTATION_COMPLETE.md

## Document Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| README.md | Current | 2026-02-02 |
| ARCHITECTURE.md | Current | 2026-02-02 |
| .claude/CLAUDE.md | Current | 2026-02-02 |
| REALTIME_IMPLEMENTATION_COMPLETE.md | Current | Phase 3 complete |
| TEST_IMPLEMENTATION_STATUS.md | Current | Ongoing |
| test/helpers/MOCK_HTTP_CLIENT.md | Current | Reference |

## Removed Documents

The following documents were removed during documentation cleanup (2026-02-02):

- **REALTIME_DESIGN.md** - Replaced by ARCHITECTURE.md
- **REALTIME_DESIGN_V2.md** - Replaced by ARCHITECTURE.md
- **WEBSOCKET_MOCK_DESIGN.md** - Consolidated into ARCHITECTURE.md
- **REALTIME_IMPLEMENTATION_STATUS.md** - Superseded by REALTIME_IMPLEMENTATION_COMPLETE.md

**Reason:** Consolidated historical design documents into single ARCHITECTURE.md that documents current state only.
