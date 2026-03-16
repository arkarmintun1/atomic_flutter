import 'package:atomic_flutter_devtools_extension/src/models/async_event.dart';
import 'package:atomic_flutter_devtools_extension/src/models/atom_data.dart';
import 'package:atomic_flutter_devtools_extension/src/models/graph_node.dart';
import 'package:atomic_flutter_devtools_extension/src/models/performance_data.dart';
import 'package:devtools_extensions/devtools_extensions.dart';

/// Client for communicating with the AtomicFlutter VM service extensions
/// running in the connected app.
///
/// Uses [serviceManager] provided by the DevTools extensions framework
/// to invoke `ext.atomic_flutter.*` service methods.
class AtomServiceClient {
  /// Fetch summary data for all registered atoms.
  static Future<List<AtomData>> getAtoms() async {
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.atomic_flutter.getAtoms',
      );

      final json = response.json ?? {};
      final atomsList = json['atoms'] as List<dynamic>? ?? [];

      return atomsList
          .map((e) => AtomData.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Service extension not registered — app may not have called enableDebugMode()
      return [];
    }
  }

  /// Fetch detailed data for a single atom.
  static Future<AtomDetailData?> getAtomDetail(String atomId) async {
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.atomic_flutter.getAtomDetail',
        args: {'atomId': atomId},
      );

      final json = response.json ?? {};
      final detail = AtomDetailData.fromJson(json);
      return detail.found ? detail : null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch performance metrics for all tracked atoms.
  static Future<List<AtomMetricsData>> getMetrics() async {
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.atomic_flutter.getMetrics',
      );

      final json = response.json ?? {};
      final metricsList = json['metrics'] as List<dynamic>? ?? [];

      return metricsList
          .map((e) => AtomMetricsData.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch memory tracking info.
  static Future<MemoryInfoData> getMemoryInfo() async {
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.atomic_flutter.getMemoryInfo',
      );

      return MemoryInfoData.fromJson(response.json ?? {});
    } catch (e) {
      return const MemoryInfoData(
        trackedAtomCount: 0,
        registeredAtomCount: 0,
        orphanedAtomCount: 0,
      );
    }
  }

  /// Fetch the dependency graph (nodes and edges).
  static Future<GraphData> getDependencyGraph() async {
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.atomic_flutter.getDependencyGraph',
      );

      return GraphData.fromJson(response.json ?? {});
    } catch (e) {
      return const GraphData(nodes: [], edges: []);
    }
  }

  /// Fetch async state transition events.
  static Future<List<AsyncEventData>> getAsyncTimeline({
    String? atomId,
  }) async {
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.atomic_flutter.getAsyncTimeline',
        args: {
          if (atomId != null) 'atomId': atomId,
        },
      );

      final json = response.json ?? {};
      final eventsList = json['events'] as List<dynamic>? ?? [];

      return eventsList
          .map((e) => AsyncEventData.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch combined performance summary.
  static Future<PerformanceSummaryData> getPerformanceSummary() async {
    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.atomic_flutter.getPerformanceSummary',
      );

      return PerformanceSummaryData.fromJson(response.json ?? {});
    } catch (e) {
      return PerformanceSummaryData.empty;
    }
  }
}
