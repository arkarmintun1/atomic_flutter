/// Performance summary data from the service layer.
class PerformanceSummaryData {
  final List<UpdateMetricData> updateMetrics;
  final List<RebuildCountData> rebuildCounts;
  final List<HotAtomData> hotAtoms;
  final List<SuspectedLeakData> suspectedLeaks;
  final int totalAtoms;
  final int totalUpdates;
  final int totalRebuilds;

  const PerformanceSummaryData({
    required this.updateMetrics,
    required this.rebuildCounts,
    required this.hotAtoms,
    required this.suspectedLeaks,
    required this.totalAtoms,
    required this.totalUpdates,
    required this.totalRebuilds,
  });

  factory PerformanceSummaryData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    return PerformanceSummaryData(
      updateMetrics: (json['updateMetrics'] as List<dynamic>? ?? [])
          .map((e) => UpdateMetricData.fromJson(e as Map<String, dynamic>))
          .toList(),
      rebuildCounts: (json['rebuildCounts'] as List<dynamic>? ?? [])
          .map((e) => RebuildCountData.fromJson(e as Map<String, dynamic>))
          .toList(),
      hotAtoms: (json['hotAtoms'] as List<dynamic>? ?? [])
          .map((e) => HotAtomData.fromJson(e as Map<String, dynamic>))
          .toList(),
      suspectedLeaks: (json['suspectedLeaks'] as List<dynamic>? ?? [])
          .map((e) => SuspectedLeakData.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAtoms: summary['totalAtoms'] as int? ?? 0,
      totalUpdates: summary['totalUpdates'] as int? ?? 0,
      totalRebuilds: summary['totalRebuilds'] as int? ?? 0,
    );
  }

  static const empty = PerformanceSummaryData(
    updateMetrics: [],
    rebuildCounts: [],
    hotAtoms: [],
    suspectedLeaks: [],
    totalAtoms: 0,
    totalUpdates: 0,
    totalRebuilds: 0,
  );
}

class UpdateMetricData {
  final String atomId;
  final int updateCount;
  final int avgIntervalMs;
  final String? lastUpdate;

  const UpdateMetricData({
    required this.atomId,
    required this.updateCount,
    required this.avgIntervalMs,
    this.lastUpdate,
  });

  factory UpdateMetricData.fromJson(Map<String, dynamic> json) {
    return UpdateMetricData(
      atomId: json['atomId'] as String? ?? '',
      updateCount: json['updateCount'] as int? ?? 0,
      avgIntervalMs: json['avgIntervalMs'] as int? ?? 0,
      lastUpdate: json['lastUpdate'] as String?,
    );
  }
}

class RebuildCountData {
  final String atomId;
  final int rebuildCount;
  final String? lastRebuild;

  const RebuildCountData({
    required this.atomId,
    required this.rebuildCount,
    this.lastRebuild,
  });

  factory RebuildCountData.fromJson(Map<String, dynamic> json) {
    return RebuildCountData(
      atomId: json['atomId'] as String? ?? '',
      rebuildCount: json['rebuildCount'] as int? ?? 0,
      lastRebuild: json['lastRebuild'] as String?,
    );
  }
}

class HotAtomData {
  final String atomId;
  final int updateCount;
  final int rebuildCount;
  final int listenerCount;
  final List<String> warnings;

  const HotAtomData({
    required this.atomId,
    required this.updateCount,
    required this.rebuildCount,
    required this.listenerCount,
    required this.warnings,
  });

  factory HotAtomData.fromJson(Map<String, dynamic> json) {
    return HotAtomData(
      atomId: json['atomId'] as String? ?? '',
      updateCount: json['updateCount'] as int? ?? 0,
      rebuildCount: json['rebuildCount'] as int? ?? 0,
      listenerCount: json['listenerCount'] as int? ?? 0,
      warnings: (json['warnings'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class SuspectedLeakData {
  final String atomId;
  final String reason;

  const SuspectedLeakData({
    required this.atomId,
    required this.reason,
  });

  factory SuspectedLeakData.fromJson(Map<String, dynamic> json) {
    return SuspectedLeakData(
      atomId: json['atomId'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }
}
