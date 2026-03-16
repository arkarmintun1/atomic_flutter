## DevTools Extension

AtomicFlutter includes a built-in Flutter DevTools extension that gives you
real-time visibility into your app's state management — right inside DevTools.

### Getting Started

1. Make sure your app calls `enableDebugMode()` before creating atoms
2. Run your app and open Flutter DevTools
3. Click the **AtomicFlutter** tab
4. Enable the extension on the first-time prompt

### Features

#### Atom Inspector
Live table of all registered atoms with search/filter, current values,
ref counts, and status badges. Click any atom to see full details.

#### Dependency Graph
Interactive visualization of atom dependencies. Computed atoms shown in green,
async atoms in orange. Click a node to highlight its full dependency chain.

#### Async Timeline
Timeline of all `AsyncAtom` operations showing state transitions
(idle → loading → success/error), durations, and error details.
Filter by atom ID to focus on specific operations.

#### Performance Dashboard
Update frequency and widget rebuild rankings with proportional bar charts.
Automatic detection of hot atoms (high update frequency) and suspected
memory leaks (atoms with no listeners and auto-dispose disabled).

#### Settings
Configurable polling intervals per panel and one-click JSON snapshot export
of all atom state and diagnostics.

### Zero Overhead in Production

All DevTools instrumentation is gated behind `Atom.debugMode`. When debug mode
is off (the default), no service extensions are registered, no events are logged,
and no rebuild counting occurs. Your release builds are completely unaffected.