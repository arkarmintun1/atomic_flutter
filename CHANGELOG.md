# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-05-30

### Added

#### Async State Management

- **AsyncAtom<T>**: New atom type for managing async operations with loading, success, error, and idle states
- **AsyncValue<T>**: Container for async data with built-in state management
- **AsyncAtomBuilder**: Widget for building UI based on async atom states
- **SimpleAsyncBuilder**: Simplified widget with sensible defaults for async state
- **AsyncRetryBuilder**: Widget with built-in retry functionality for failed operations
- **AsyncRefreshBuilder**: Widget with pull-to-refresh support

#### Advanced Extensions

- **AsyncAtom Extensions**:
  - `debounceAsync()`: Debounce async state updates
  - `mapAsync()`: Transform async values
  - `executeIfNotLoading()`: Conditional execution
  - `executeWithRetry()`: Automatic retry on failure
  - `chain()`: Chain async operations
  - `cached()`: Cache async results with TTL
- **Atom to AsyncAtom Conversion**:
  - `toAsync()`: Convert regular atoms to async atoms
  - `asyncMap()`: Create async atoms from sync atoms

#### Computed Async Atoms

- **computedAsync()**: Create computed atoms that depend on other atoms and execute async operations
- **combineAsync()**: Combine multiple async atoms into a single async atom

#### Enhanced Core Features

- **AtomFamily**: Create related atoms with different keys
- **AtomConsumer**: Widget that provides atom value and optional static child
- **MultiAtomBuilder**: Widget that rebuilds when any of multiple atoms change
- **Advanced Extensions**:
  - `map()`: Transform atom values
  - `where()`: Filter atom updates
  - `combine()`: Combine two atoms
  - `compute()`: Create computed atoms (convenience method)

#### Performance & Debugging

- **AtomPerformanceMonitor**: Track atom update frequency and performance metrics
- **AtomMemoryTracker**: Monitor memory usage and atom lifecycle
- **Enhanced Debug Tools**: Better debugging with performance insights

#### Memory Management

- **Improved Auto-disposal**: More sophisticated reference counting and cleanup
- **Weak References**: Proper handling of dependencies to prevent memory leaks
- **Batch Operations**: Efficient handling of multiple atom updates
- **Timer Management**: Proper cleanup of debounce/throttle timers

### Enhanced

#### Core Atom Improvements

- Better equality checking and change detection
- Enhanced listener management with proper cleanup
- Improved batch update handling
- More robust dispose lifecycle

#### Widget Improvements

- Better performance with selective rebuilds
- Improved error handling in widgets
- Enhanced lifecycle management
- More efficient listener registration

#### Extension Enhancements

- More powerful stream conversion with proper cleanup
- Better debounce/throttle implementations
- Enhanced effect system with cleanup functions
- Improved selector performance

### Breaking Changes

- Minimum Flutter version increased to 1.17.0
- Some internal APIs have changed (extension implementations)
- Debug registry behavior has been improved

### Migration Guide

- No breaking changes to public APIs
- Extensions now auto-dispose by default for better memory management
- Debug mode registration is now more efficient

## [0.1.3] - 2025-05-20

### Changed

- Update readme

## [0.1.2] - 2025-03-25

### Fixed

- `effect` function listener removal

## [0.1.1] - 2025-03-17

### Fixed

- `computed` function exception

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
