# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
