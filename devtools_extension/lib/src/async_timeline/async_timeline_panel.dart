import 'dart:async';

import 'package:atomic_flutter_devtools_extension/src/models/models.dart';
import 'package:atomic_flutter_devtools_extension/src/services/atom_service_client.dart';
import 'package:flutter/material.dart';

/// Timeline visualization of AsyncAtom state transitions.
///
/// Shows each async operation as a row with timing, status, and
/// optional error details.
class AsyncTimelinePanel extends StatefulWidget {
  const AsyncTimelinePanel({super.key});

  @override
  State<AsyncTimelinePanel> createState() => _AsyncTimelinePanelState();
}

class _AsyncTimelinePanelState extends State<AsyncTimelinePanel> {
  List<AsyncEventData> _events = [];
  List<AsyncOperation> _operations = [];
  bool _isLoading = true;
  String? _filterAtomId;
  AsyncOperation? _selectedOperation;
  Timer? _pollTimer;

  // All unique atom IDs seen in events
  Set<String> _atomIds = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final events = await AtomServiceClient.getAsyncTimeline(
        atomId: _filterAtomId,
      );
      if (!mounted) return;

      setState(() {
        _events = events;
        _operations = groupEventsIntoOperations(events);
        _atomIds = events.map((e) => e.atomId).toSet();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_events.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildToolbar(context),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildOperationList(context),
              ),
              if (_selectedOperation != null) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 280,
                  child: _buildDetailPanel(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);

    final successCount = _operations.where((o) => o.isSuccess).length;
    final errorCount = _operations.where((o) => o.isError).length;
    final loadingCount = _operations.where((o) => o.isLoading).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Atom filter dropdown
          if (_atomIds.length > 1) ...[
            SizedBox(
              height: 32,
              child: DropdownButton<String?>(
                value: _filterAtomId,
                hint: Text('All atoms', style: theme.textTheme.bodySmall),
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All atoms'),
                  ),
                  ..._atomIds.map((id) => DropdownMenuItem(
                        value: id,
                        child: Text(id,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12)),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterAtomId = value;
                    _selectedOperation = null;
                  });
                  _fetchData();
                },
              ),
            ),
            const SizedBox(width: 16),
          ],
          // Summary chips
          _CountChip(
              count: successCount, label: 'success', color: Colors.green),
          const SizedBox(width: 8),
          _CountChip(count: errorCount, label: 'errors', color: Colors.red),
          const SizedBox(width: 8),
          if (loadingCount > 0)
            _CountChip(
                count: loadingCount, label: 'loading', color: Colors.blue),
          const Spacer(),
          Text(
            '${_operations.length} operations',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh',
            onPressed: _fetchData,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildOperationList(BuildContext context) {
    final theme = Theme.of(context);

    // Show most recent first
    final reversed = _operations.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                  flex: 2,
                  child: Text('Time',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 3,
                  child: Text('Atom',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('Status',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('Duration',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.bold))),
              const Expanded(flex: 4, child: SizedBox.shrink()), // bar space
            ],
          ),
        ),
        const Divider(height: 1),
        // Rows
        Expanded(
          child: ListView.builder(
            itemCount: reversed.length,
            itemBuilder: (context, index) {
              final op = reversed[index];
              final isSelected = _selectedOperation == op;
              return _buildOperationRow(theme, op, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOperationRow(
      ThemeData theme, AsyncOperation op, bool isSelected) {
    final (statusColor, statusIcon) = _statusInfo(op);

    return InkWell(
      onTap: () => setState(() {
        _selectedOperation = isSelected ? null : op;
      }),
      child: Container(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Time
            Expanded(
              flex: 2,
              child: Text(
                op.loadingEvent.timeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            // Atom ID
            Expanded(
              flex: 3,
              child: Text(
                op.atomId,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Status badge
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    op.statusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Duration
            Expanded(
              flex: 2,
              child: Text(
                op.isComplete ? op.resultEvent!.durationLabel : '...',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
            // Duration bar
            Expanded(
              flex: 4,
              child: _DurationBar(
                durationMs: op.durationMs,
                maxDurationMs: _maxDurationMs,
                color: statusColor,
                isLoading: op.isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _maxDurationMs {
    if (_operations.isEmpty) return 1000;
    final max =
        _operations.map((o) => o.durationMs).fold(0, (a, b) => a > b ? a : b);
    return max > 0 ? max : 1000;
  }

  (Color, IconData) _statusInfo(AsyncOperation op) {
    if (op.isLoading) return (Colors.blue, Icons.hourglass_top);
    if (op.isSuccess) return (Colors.green, Icons.check_circle_outline);
    return (Colors.red, Icons.error_outline);
  }

  Widget _buildDetailPanel(BuildContext context) {
    final theme = Theme.of(context);
    final op = _selectedOperation!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Operation Detail',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _selectedOperation = null),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _DetailRow(label: 'Atom', value: op.atomId),
              _DetailRow(label: 'Started', value: op.loadingEvent.timeLabel),
              _DetailRow(label: 'Status', value: op.statusLabel),
              if (op.isComplete)
                _DetailRow(
                    label: 'Duration', value: op.resultEvent!.durationLabel),
              _DetailRow(label: 'From State', value: op.loadingEvent.fromState),
              if (op.resultEvent != null)
                _DetailRow(label: 'To State', value: op.resultEvent!.toState),
              if (op.isError && op.resultEvent?.error != null) ...[
                const SizedBox(height: 12),
                Text('Error',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: SelectableText(
                    op.resultEvent!.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timeline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No async operations recorded',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Execute async operations on AsyncAtom instances to see the timeline.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }
}

class _DurationBar extends StatelessWidget {
  final int durationMs;
  final int maxDurationMs;
  final Color color;
  final bool isLoading;

  const _DurationBar({
    required this.durationMs,
    required this.maxDurationMs,
    required this.color,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 8,
          child: LinearProgressIndicator(
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color.withOpacity(0.5)),
          ),
        ),
      );
    }

    final fraction =
        maxDurationMs > 0 ? (durationMs / maxDurationMs).clamp(0.02, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 8,
            width: constraints.maxWidth * fraction,
            decoration: BoxDecoration(
              color: color.withOpacity(0.6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      },
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _CountChip({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count $label',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
