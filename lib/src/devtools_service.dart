import 'dart:convert';
import 'dart:developer' as developer;

import 'package:atomic_flutter/src/async_atom.dart';
import 'package:atomic_flutter/src/debug.dart';

/// Service layer for AtomicFlutter DevTools extension.
///
/// Registers Dart VM service extensions that the DevTools extension
/// can call to query atom state, metrics, and dependency information.
///
/// This is automatically registered when [enableDebugMode] is called.
/// All service extensions are no-ops when debug mode is off.
class AtomicFlutterDevToolsService {
  static bool _registered = false;

  /// Register all VM service extensions for DevTools communication.
  ///
  /// Safe to call multiple times — only registers once.
  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;

    _registerGetAtoms();
    _registerGetAtomDetail();
    _registerGetPerformanceSummary();
    _registerGetMemoryInfo();
    _registerGetDependencyGraph();
    _registerGetAsyncTimeline();

    developer.log(
      'AtomicFlutter DevTools service extensions registered',
      name: 'atomic_flutter',
    );
  }

  /// ext.atomic_flutter.getAtoms
  ///
  /// Returns a JSON list of all registered atoms with summary info.
  static void _registerGetAtoms() {
    developer.registerExtension(
      'ext.atomic_flutter.getAtoms',
      (method, params) async {
        try {
          final atoms = AtomDebugger.getAllAtoms().map((atom) {
            final valueStr = atom.value.toString();
            final isAsync = atom.value is AsyncValue;

            return <String, dynamic>{
              'id': atom.id,
              'type': atom.value.runtimeType.toString(),
              'value': valueStr.length > 200
                  ? '${valueStr.substring(0, 200)}...'
                  : valueStr,
              'refCount': atom.refCount,
              'hasListeners': atom.hasListeners,
              'autoDispose': atom.autoDispose,
              'isAsync': isAsync,
              if (isAsync) 'asyncState': (atom.value as AsyncValue).state.name,
              'isComputed': atom.isComputed,
              'listenerCount': atom.listenerCount,
              'dependencyIds': atom.debugDependencyIds,
              'dependentIds': atom.debugDependentIds,
            };
          }).toList();

          return developer.ServiceExtensionResponse.result(
            json.encode({'atoms': atoms, 'count': atoms.length}),
          );
        } catch (e, stack) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to get atoms: $e\n$stack',
          );
        }
      },
    );
  }

  /// ext.atomic_flutter.getAtomDetail
  ///
  /// Returns detailed info for a single atom by ID.
  /// Params: { "atomId": "some_atom_id" }
  static void _registerGetAtomDetail() {
    developer.registerExtension(
      'ext.atomic_flutter.getAtomDetail',
      (method, params) async {
        try {
          final atomId = params['atomId'];
          if (atomId == null) {
            return developer.ServiceExtensionResponse.error(
              developer.ServiceExtensionResponse.extensionError,
              'Missing required parameter: atomId',
            );
          }

          final allAtoms = AtomDebugger.getAllAtoms();
          final atom = allAtoms.where((a) => a.id == atomId).firstOrNull;

          if (atom == null) {
            return developer.ServiceExtensionResponse.result(
              json.encode({'found': false}),
            );
          }

          final isAsync = atom.value is AsyncValue;

          final detail = <String, dynamic>{
            'found': true,
            'id': atom.id,
            'type': atom.value.runtimeType.toString(),
            'value': atom.value.toString(),
            'refCount': atom.refCount,
            'hasListeners': atom.hasListeners,
            'autoDispose': atom.autoDispose,
            'disposeTimeout': atom.disposeTimeout?.inMilliseconds,
            'isAsync': isAsync,
          };

          if (isAsync) {
            final asyncValue = atom.value as AsyncValue;
            detail['asyncState'] = asyncValue.state.name;
            detail['hasData'] = asyncValue.data != null;
            detail['hasError'] = asyncValue.hasError;
            if (asyncValue.hasError) {
              detail['error'] = asyncValue.error.toString();
            }
          }

          return developer.ServiceExtensionResponse.result(
            json.encode(detail),
          );
        } catch (e, stack) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to get atom detail: $e\n$stack',
          );
        }
      },
    );
  }

  /// ext.atomic_flutter.getPerformanceSummary
  ///
  /// Returns combined performance metrics: update rates, rebuild counts,
  /// and hot atom warnings.
  static void _registerGetPerformanceSummary() {
    developer.registerExtension(
      'ext.atomic_flutter.getPerformanceSummary',
      (method, params) async {
        try {
          final metrics = AtomPerformanceMonitor.getAllMetrics();
          final rebuildCounts = WidgetRebuildTracker.getAllRebuildCounts();
          final allAtoms = AtomDebugger.getAllAtoms();

          // Serialize update metrics
          final updateMetrics = metrics.entries.map((entry) {
            final m = entry.value;
            return <String, dynamic>{
              'atomId': m.atomId,
              'updateCount': m.updateCount,
              'avgIntervalMs': m.averageUpdateInterval.inMilliseconds,
              'lastUpdate': m.lastUpdate?.toIso8601String(),
            };
          }).toList();

          // Serialize rebuild counts
          final rebuilds = rebuildCounts.entries.map((entry) {
            return <String, dynamic>{
              'atomId': entry.key,
              'rebuildCount': entry.value,
              'lastRebuild': WidgetRebuildTracker.getLastRebuildTime(entry.key)
                  ?.toIso8601String(),
            };
          }).toList();

          // Detect hot atoms (>60 updates or rebuilds)
          final hotAtoms = <Map<String, dynamic>>[];
          for (final m in metrics.values) {
            final rebuildsForAtom = rebuildCounts[m.atomId] ?? 0;
            final warnings = <String>[];

            if (m.updateCount > 60) {
              warnings.add('High update frequency: ${m.updateCount} updates');
            }
            if (rebuildsForAtom > 60) {
              warnings.add('High rebuild count: $rebuildsForAtom rebuilds');
            }

            // Check for atoms with many listeners
            final atom = allAtoms.where((a) => a.id == m.atomId).firstOrNull;
            if (atom != null && atom.listenerCount > 20) {
              warnings.add('Many listeners: ${atom.listenerCount}');
            }

            if (warnings.isNotEmpty) {
              hotAtoms.add({
                'atomId': m.atomId,
                'updateCount': m.updateCount,
                'rebuildCount': rebuildsForAtom,
                'listenerCount': atom?.listenerCount ?? 0,
                'warnings': warnings,
              });
            }
          }

          // Check for suspected leaks (no listeners, not auto-disposing)
          final suspectedLeaks = allAtoms
              .where(
                  (a) => !a.hasListeners && a.refCount <= 0 && !a.autoDispose)
              .map((a) => {
                    'atomId': a.id,
                    'reason': 'No listeners, auto-dispose disabled',
                  })
              .toList();

          return developer.ServiceExtensionResponse.result(
            json.encode({
              'updateMetrics': updateMetrics,
              'rebuildCounts': rebuilds,
              'hotAtoms': hotAtoms,
              'suspectedLeaks': suspectedLeaks,
              'summary': {
                'totalAtoms': allAtoms.length,
                'totalUpdates':
                    metrics.values.fold(0, (sum, m) => sum + m.updateCount),
                'totalRebuilds':
                    rebuildCounts.values.fold(0, (sum, c) => sum + c),
              },
            }),
          );
        } catch (e, stack) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to get performance summary: $e\n$stack',
          );
        }
      },
    );
  }

  /// ext.atomic_flutter.getMemoryInfo
  ///
  /// Returns memory tracking summary.
  static void _registerGetMemoryInfo() {
    developer.registerExtension(
      'ext.atomic_flutter.getMemoryInfo',
      (method, params) async {
        try {
          final allAtoms = AtomDebugger.getAllAtoms();
          final orphanedCount =
              allAtoms.where((a) => !a.hasListeners && a.refCount <= 0).length;

          return developer.ServiceExtensionResponse.result(
            json.encode({
              'trackedAtomCount': AtomMemoryTracker.trackedAtomCount,
              'registeredAtomCount': allAtoms.length,
              'orphanedAtomCount': orphanedCount,
              'atomsByAutoDispose': {
                'enabled': allAtoms.where((a) => a.autoDispose).length,
                'disabled': allAtoms.where((a) => !a.autoDispose).length,
              },
            }),
          );
        } catch (e, stack) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to get memory info: $e\n$stack',
          );
        }
      },
    );
  }

  /// ext.atomic_flutter.getDependencyGraph
  ///
  /// Returns nodes and edges for the atom dependency graph.
  static void _registerGetDependencyGraph() {
    developer.registerExtension(
      'ext.atomic_flutter.getDependencyGraph',
      (method, params) async {
        try {
          final allAtoms = AtomDebugger.getAllAtoms();

          final nodes = allAtoms.map((atom) {
            final isAsync = atom.value is AsyncValue;
            String atomType = 'atom';
            if (atom.isComputed) {
              atomType = 'computed';
            } else if (isAsync) {
              atomType = 'async';
            }

            return <String, dynamic>{
              'id': atom.id,
              'type': atomType,
              'valueType': atom.value.runtimeType.toString(),
              'refCount': atom.refCount,
              'listenerCount': atom.listenerCount,
              'dependencyCount': atom.debugDependencyIds.length,
              'dependentCount': atom.debugDependentIds.length,
            };
          }).toList();

          // Build edges from dependency relationships
          final edges = <Map<String, dynamic>>[];
          for (final atom in allAtoms) {
            for (final depId in atom.debugDependencyIds) {
              edges.add({
                'from': depId,
                'to': atom.id,
                'type': 'dependency',
              });
            }
          }

          return developer.ServiceExtensionResponse.result(
            json.encode({
              'nodes': nodes,
              'edges': edges,
              'nodeCount': nodes.length,
              'edgeCount': edges.length,
            }),
          );
        } catch (e, stack) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to get dependency graph: $e\n$stack',
          );
        }
      },
    );
  }

  /// ext.atomic_flutter.getAsyncTimeline
  ///
  /// Returns async state transition events.
  /// Params (optional): { "atomId": "filter_by_id" }
  static void _registerGetAsyncTimeline() {
    developer.registerExtension(
      'ext.atomic_flutter.getAsyncTimeline',
      (method, params) async {
        try {
          final atomId = params['atomId'];
          final events = AsyncEventLog.getEvents(atomId: atomId);

          final serialized = events.map((e) => e.toJson()).toList();

          return developer.ServiceExtensionResponse.result(
            json.encode({
              'events': serialized,
              'count': serialized.length,
            }),
          );
        } catch (e, stack) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'Failed to get async timeline: $e\n$stack',
          );
        }
      },
    );
  }
}
