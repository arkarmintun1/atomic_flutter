# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.1] - 2026-03-22

### Fixed

- **`atomicUpdate()` rollback** — atoms now restore their previous values when an error is thrown inside the update block, preventing inconsistent state
- **`AsyncValue.hasValue`** — correctly returns `true` for nullable success types with `null` data
- **`AsyncValue.value`** — uses safe `as T` cast instead of `!` to support nullable type parameters
- **`AsyncAtom.cancel()` / `clear()`** — bypass middleware via `setDirect()` to avoid unintended side effects
- **`asStream()`** — changed to single-subscription `StreamController` with lazy listener setup, preventing resource leaks
- **`select()`** — now delegates to `computed()` for proper read-only semantics
- **`throttle()`** — added trailing-edge emission so the last value in a throttle window is never lost
- **`combine()`** — `onDispose` callbacks now return removal functions; each source properly cleans up the other on disposal
- **`persistAtom()` race condition** — user `set()` calls during async storage restore now take priority over the persisted value; restored values no longer trigger a redundant write-back
- **`WatchAtom` mixin** — fixed subscription tracking so `_watching` is cleared on the first `watch()` of each build pass instead of inside the listener
- **`executeWithRetry()`** — checks `isDisposed` after each retry delay to stop retrying disposed atoms
- **`AtomFamily.call()`** — auto-removes disposed atoms from the internal map and returns a fresh instance
- **`AtomFamily.dispose()`** — snapshots the map before iterating to prevent `ConcurrentModificationError`
- **`AtomHistory` lint** — replaced `!` with `as T` casts on nullable type parameters to fix `null_check_on_nullable_type_parameter`
- **`MultiAtomBuilder` equality** — `_listsEqual` now handles lists of different lengths correctly
- **Example app** — fixed `AsyncBuilder` → `AsyncAtomBuilder`, wrong `success:` parameter name, and `select()` leak in `build()`
- **CI analysis** — excluded `devtools_extension/` from `flutter analyze` to prevent false failures from its unresolved dependencies

### Added

- **`Atom.setDirect()`** — `@protected` method for cross-library access to bypass middleware
- **`Atom.onDispose()` removal** — now returns a `VoidCallback` to unregister the callback; runs immediately if atom is already disposed
- **CI workflow** — GitHub Actions workflow for `flutter analyze` and `flutter test` on push/PR to `main`
- **README badge** — test status badge
- **New tests** — `onDispose` removal, `AtomFamily` auto-cleanup, `atomicUpdate` rollback, `AsyncValue.hasValue` for nullable types, `persistAtom` race conditions, throttle trailing edge, and more

## [0.5.0] - 2026-03-18

### Added

- **`WatchAtom` mixin** — subscribe to atoms directly inside `build()` with no `AtomBuilder` wrapper; subscriptions are reconciled automatically after each frame
- **`AtomMiddleware`** — intercept and transform values on every `set()` call; supports global middleware (`Atom.addMiddleware`) and per-atom transformers via the `middleware` constructor parameter
- **`LoggingMiddleware`** — built-in middleware that logs every state change in debug mode at zero cost in release builds
- **`atomicUpdate()`** — defers all listener notifications until every atom in the block has been updated; nested calls are fully supported via a depth counter
- **`AtomHistory<T>`** — wraps any `Atom<T>` with a bounded undo/redo stack backed by a fixed-capacity ring buffer; `canUndo` and `canRedo` exposed as `Atom<bool>` for reactive UI
- **`persistAtom()`** — creates an atom whose value is automatically saved to and restored from any `AtomStorage` backend
- **`AtomStorage`** — storage abstraction with `read` / `write` / `delete`; implement for any key-value store (SharedPreferences, Hive, etc.)
- **`InMemoryAtomStorage`** — in-memory `AtomStorage` implementation for tests
- **Custom `equals` on `AtomSelector`** — prevents rebuilds when a custom equality function says the selected value has not changed

### Changed

- **`AtomBuilder` builder signature** now includes an optional `child` parameter: `Widget Function(BuildContext, T, Widget?)` — allows passing a static sub-tree that is not rebuilt on atom changes
- **`AsyncAtomBuilder`** is now the single async widget — `AsyncBuilder` has been removed; providing `operation` enables both pull-to-refresh and a retry button with no extra flags
- **`select()` extension** now returns `Atom<S>` (a derived atom) instead of a widget
- **`atomicUpdate()`** replaces `batchAtomUpdates` — the old function has been removed
- **`_globalBatching`** replaced by `_globalBatchDepth` counter so nested `atomicUpdate` calls flush only when the outermost block exits
- **`_isBatching`** replaced by `_batchDepth` counter on `Atom` so nested `batch()` calls on the same atom flush only when the outermost call exits

### Fixed

- `_notifyListeners` now snapshots the listener set before iterating, preventing `ConcurrentModificationError` when a listener removes itself during notification
- Duplicate atoms in `MultiAtomBuilder`'s atom list no longer register multiple listeners, preventing a listener leak
- `select()` listener now wraps the selector call in a try-catch, consistent with `map()` and `where()`

### Removed

- `AtomConsumer` — use `AtomBuilder` instead
- `AsyncBuilder` — use `AsyncAtomBuilder` instead
- `batchAtomUpdates` — use `atomicUpdate` instead

## [0.4.1] - 2026-03-17

### Fixed

- Fix material icons

## [0.4.0] - 2026-03-17

### Added

- **DevTools Extension**: Built-in Flutter DevTools extension with four feature panels:
  - **Atom Inspector**: Live table of all atoms with search, filtering, and detail view
  - **Dependency Graph**: Interactive force-directed graph visualization of atom dependencies
  - **Async Timeline**: Timeline of AsyncAtom state transitions with duration bars and error details
  - **Performance Dashboard**: Update frequency and widget rebuild rankings with hot atom detection and memory leak warnings
  - **Settings**: Configurable polling intervals and JSON snapshot export
- `AtomicFlutterDevToolsService` — VM service extension layer for DevTools communication
- `AsyncAtomEvent` and `AsyncEventLog` — ring buffer for async state transition recording
- `WidgetRebuildTracker` — tracks AtomBuilder widget rebuild counts per atom
- Debug getters on `Atom`: `debugDependencyIds`, `debugDependentIds`, `isComputed`, `listenerCount`
- `enableDebugMode()` now automatically registers DevTools service extensions and enables performance monitoring

### Changed

- `enableDebugMode()` now also enables `AtomPerformanceMonitor` and registers DevTools service extensions

### Notes

- All DevTools instrumentation is zero-cost when debug mode is off
- No new runtime dependencies — uses only `dart:developer` for service extensions
- The extension is bundled with the package — no separate dependency needed

## [0.3.0] - 2025-12-04

### Fixed

**Critical Memory Leak Fixes:**
- Fixed memory leaks in all core extension methods (`debounce`, `throttle`, `map`, `where`, `combine`)
- Fixed memory leaks in all async extension methods (`debounceAsync`, `mapAsync`, `chain`, `cached`, `asyncMap`)
- Fixed `StreamController` not being disposed when atom is disposed in `asStream()`
- All extension methods now properly cleanup listeners in both directions (source → derived and derived → source)
- Timer cleanup added to prevent resource leaks in debounce, throttle, and cached operations

**Type Safety & Error Prevention:**
- Computed atoms now throw `UnsupportedError` when attempting to mutate via `set()` or `update()`
- Added circular dependency detection in `computed()` with clear error messages
- Prevents infinite loops from circular atom dependencies

**Robustness & Error Handling:**
- Listener errors are now caught and logged instead of crashing the app
- Errors in computed atom recomputation no longer prevent other listeners from executing
- Added try-catch blocks to all extension methods with error logging in debug mode

**Edge Cases & API Improvements:**
- `combineAsync()` now handles empty list input (returns success with empty list)
- `chain()` now propagates initial state correctly (idle/loading/error states)
- `combine()` now includes error handling for tuple creation

### Added

- Comprehensive test suite with 31+ new test cases covering:
  - Memory leak detection and prevention
  - Computed atom mutation attempts
  - Circular dependency detection
  - Error handling in listeners and computed atoms
  - Edge cases in async operations
  - Bidirectional cleanup verification

### Changed

- All extension methods now use named listener functions for proper cleanup
- Improved documentation for `combineAsync()` explaining behavior with empty lists
- Enhanced error messages for computed atom mutations

## [0.2.4] - 2025-08-29

### Changed

- Add `runImmediately` option to effect for execution control

## [0.2.3] - 2025-08-11

### Fixed

- Clean up whitespace in async widget and test files
- Update async handling and improve code structure

## [0.2.2] - 2025-08-11

### Fixed

- Unused local variables in debug tests

## [0.2.1] - 2025-08-11

### Fixed

- Code linting issues

## [0.2.0] - 2025-08-11

### Added

- **AsyncAtom**: New async state management with `AsyncValue<T>` wrapper
- **AsyncState enum**: `idle`, `loading`, `success`, and `error` states
- **AsyncAtomBuilder**: Widget for building UI based on async atom states
- **AsyncBuilder**: Simplified async widget with retry and refresh support
- **Async Extensions**:
  - `debounceAsync()` - Debounced async operations
  - `mapAsync()` - Transform async values
  - `executeIfNotLoading()` - Conditional execution
  - `executeWithRetry()` - Retry failed operations with exponential backoff
  - `chain()` - Chain async operations
  - `cached()` - Create cached async operations with TTL
  - `toAsync()` - Convert regular atoms to async atoms
  - `asyncMap()` - Create async atoms from regular atom changes
- **Global Async Functions**:
  - `computedAsync()` - Create debounced computed async atoms
  - `combineAsync()` - Combine multiple async atoms
- **Memory Management**: Enhanced automatic cleanup for async operations
- **Debug Support**: Extended debug utilities for async atoms
- **Comprehensive Test Coverage**: Added extensive tests for all new features

### Changed

- Enhanced core `Atom` class with improved async support
- Updated extension methods with better async integration
- Improved documentation with async examples

### Fixed

- Async atom test stability improvements
- Memory leak prevention in async operations

## [0.1.3] - 2025-05-20

### Changed

- Update readme

## [0.1.2] - 2025-03-25

### Fixed

- `effect` function listener removal

## [0.1.1] - 2025-03-17

### Fixed

- `computed` function expection

### Changed

- Update example with complete setup for e-commerce app

## [0.1.0] - 2025-03-17

### Added

- Initial beta release
- Core `Atom` class for state management
- `computed` function for derived state
- UI widgets: `AtomBuilder`, `MultiAtomBuilder`, and `AtomSelector`
- Extension methods: `effect`, `asStream`, `select`, `debounce`, and `throttle`
- Automatic memory management with reference counting
- Debug utilities for tracking atom state and changes
- Comprehensive documentation and examples
