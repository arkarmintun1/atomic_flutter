/// A recorded async state transition event.
class AsyncEventData {
  final String atomId;
  final DateTime timestamp;
  final String fromState;
  final String toState;
  final int durationMs;
  final String? error;

  const AsyncEventData({
    required this.atomId,
    required this.timestamp,
    required this.fromState,
    required this.toState,
    required this.durationMs,
    this.error,
  });

  factory AsyncEventData.fromJson(Map<String, dynamic> json) {
    return AsyncEventData(
      atomId: json['atomId'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      fromState: json['fromState'] as String? ?? '',
      toState: json['toState'] as String? ?? '',
      durationMs: json['durationMs'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }

  bool get isTransitionToLoading => toState == 'loading';
  bool get isTransitionToSuccess => toState == 'success';
  bool get isTransitionToError => toState == 'error';

  String get durationLabel {
    if (durationMs == 0) return '';
    if (durationMs < 1000) return '${durationMs}ms';
    return '${(durationMs / 1000).toStringAsFixed(1)}s';
  }

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

/// A paired operation: loading start → result (success or error).
class AsyncOperation {
  final String atomId;
  final AsyncEventData loadingEvent;
  final AsyncEventData? resultEvent; // null if still loading

  const AsyncOperation({
    required this.atomId,
    required this.loadingEvent,
    this.resultEvent,
  });

  bool get isComplete => resultEvent != null;
  bool get isSuccess => resultEvent?.isTransitionToSuccess ?? false;
  bool get isError => resultEvent?.isTransitionToError ?? false;
  bool get isLoading => !isComplete;

  int get durationMs => resultEvent?.durationMs ?? 0;

  String get statusLabel {
    if (isLoading) return 'loading...';
    if (isSuccess) return 'success';
    return 'error';
  }
}

/// Groups raw events into paired operations for timeline display.
List<AsyncOperation> groupEventsIntoOperations(List<AsyncEventData> events) {
  final operations = <AsyncOperation>[];
  final pendingLoads = <String, AsyncEventData>{}; // atomId -> loading event

  for (final event in events) {
    if (event.isTransitionToLoading) {
      pendingLoads[event.atomId] = event;
    } else if (event.isTransitionToSuccess || event.isTransitionToError) {
      final loadEvent = pendingLoads.remove(event.atomId);
      if (loadEvent != null) {
        operations.add(AsyncOperation(
          atomId: event.atomId,
          loadingEvent: loadEvent,
          resultEvent: event,
        ));
      }
    }
  }

  // Add still-loading operations
  for (final entry in pendingLoads.entries) {
    operations.add(AsyncOperation(
      atomId: entry.key,
      loadingEvent: entry.value,
    ));
  }

  return operations;
}
