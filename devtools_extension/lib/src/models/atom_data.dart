/// Represents summary data for a single atom, deserialized from the
/// `ext.atomic_flutter.getAtoms` VM service response.
class AtomData {
  final String id;
  final String type;
  final String value;
  final int refCount;
  final bool hasListeners;
  final bool autoDispose;
  final bool isAsync;
  final String? asyncState;

  const AtomData({
    required this.id,
    required this.type,
    required this.value,
    required this.refCount,
    required this.hasListeners,
    required this.autoDispose,
    required this.isAsync,
    this.asyncState,
  });

  factory AtomData.fromJson(Map<String, dynamic> json) {
    return AtomData(
      id: json['id'] as String? ?? 'unknown',
      type: json['type'] as String? ?? 'dynamic',
      value: json['value'] as String? ?? '',
      refCount: json['refCount'] as int? ?? 0,
      hasListeners: json['hasListeners'] as bool? ?? false,
      autoDispose: json['autoDispose'] as bool? ?? true,
      isAsync: json['isAsync'] as bool? ?? false,
      asyncState: json['asyncState'] as String?,
    );
  }

  /// Short display string for the value column.
  String get displayValue {
    if (value.length > 80) {
      return '${value.substring(0, 80)}...';
    }
    return value;
  }

  /// Human-readable status label.
  String get statusLabel {
    if (isAsync && asyncState != null) {
      return asyncState!;
    }
    if (!hasListeners) return 'unused';
    return 'active';
  }
}

/// Represents detailed data for a single atom, deserialized from the
/// `ext.atomic_flutter.getAtomDetail` VM service response.
class AtomDetailData {
  final bool found;
  final String id;
  final String type;
  final String value;
  final int refCount;
  final bool hasListeners;
  final bool autoDispose;
  final int? disposeTimeoutMs;
  final bool isAsync;
  final String? asyncState;
  final bool? hasData;
  final bool? hasError;
  final String? error;

  const AtomDetailData({
    required this.found,
    required this.id,
    required this.type,
    required this.value,
    required this.refCount,
    required this.hasListeners,
    required this.autoDispose,
    this.disposeTimeoutMs,
    required this.isAsync,
    this.asyncState,
    this.hasData,
    this.hasError,
    this.error,
  });

  factory AtomDetailData.fromJson(Map<String, dynamic> json) {
    return AtomDetailData(
      found: json['found'] as bool? ?? false,
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      value: json['value'] as String? ?? '',
      refCount: json['refCount'] as int? ?? 0,
      hasListeners: json['hasListeners'] as bool? ?? false,
      autoDispose: json['autoDispose'] as bool? ?? true,
      disposeTimeoutMs: json['disposeTimeout'] as int?,
      isAsync: json['isAsync'] as bool? ?? false,
      asyncState: json['asyncState'] as String?,
      hasData: json['hasData'] as bool?,
      hasError: json['hasError'] as bool?,
      error: json['error'] as String?,
    );
  }
}

/// Summary of performance metrics for one atom.
class AtomMetricsData {
  final String atomId;
  final int updateCount;
  final int avgIntervalMs;
  final String? lastUpdate;

  const AtomMetricsData({
    required this.atomId,
    required this.updateCount,
    required this.avgIntervalMs,
    this.lastUpdate,
  });

  factory AtomMetricsData.fromJson(Map<String, dynamic> json) {
    return AtomMetricsData(
      atomId: json['atomId'] as String? ?? '',
      updateCount: json['updateCount'] as int? ?? 0,
      avgIntervalMs: json['avgIntervalMs'] as int? ?? 0,
      lastUpdate: json['lastUpdate'] as String?,
    );
  }
}

/// Memory info summary.
class MemoryInfoData {
  final int trackedAtomCount;
  final int registeredAtomCount;
  final int orphanedAtomCount;

  const MemoryInfoData({
    required this.trackedAtomCount,
    required this.registeredAtomCount,
    required this.orphanedAtomCount,
  });

  factory MemoryInfoData.fromJson(Map<String, dynamic> json) {
    return MemoryInfoData(
      trackedAtomCount: json['trackedAtomCount'] as int? ?? 0,
      registeredAtomCount: json['registeredAtomCount'] as int? ?? 0,
      orphanedAtomCount: json['orphanedAtomCount'] as int? ?? 0,
    );
  }
}
