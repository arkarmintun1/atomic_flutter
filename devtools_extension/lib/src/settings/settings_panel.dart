import 'dart:convert';

import 'package:atomic_flutter_devtools_extension/src/services/atom_service_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Settings and utilities panel.
///
/// Provides controls for polling intervals and a snapshot export button.
class SettingsPanel extends StatefulWidget {
  final Duration atomPollInterval;
  final Duration graphPollInterval;
  final Duration timelinePollInterval;
  final Duration perfPollInterval;
  final ValueChanged<Duration> onAtomPollChanged;
  final ValueChanged<Duration> onGraphPollChanged;
  final ValueChanged<Duration> onTimelinePollChanged;
  final ValueChanged<Duration> onPerfPollChanged;

  const SettingsPanel({
    super.key,
    required this.atomPollInterval,
    required this.graphPollInterval,
    required this.timelinePollInterval,
    required this.perfPollInterval,
    required this.onAtomPollChanged,
    required this.onGraphPollChanged,
    required this.onTimelinePollChanged,
    required this.onPerfPollChanged,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _isExporting = false;

  Future<void> _exportSnapshot() async {
    setState(() => _isExporting = true);

    try {
      final atoms = await AtomServiceClient.getAtoms();
      final memoryInfo = await AtomServiceClient.getMemoryInfo();
      final graph = await AtomServiceClient.getDependencyGraph();
      final timeline = await AtomServiceClient.getAsyncTimeline();
      final performance = await AtomServiceClient.getPerformanceSummary();

      final snapshot = {
        'exportedAt': DateTime.now().toIso8601String(),
        'atoms': atoms
            .map((a) => {
                  'id': a.id,
                  'type': a.type,
                  'value': a.value,
                  'refCount': a.refCount,
                  'hasListeners': a.hasListeners,
                  'autoDispose': a.autoDispose,
                  'isAsync': a.isAsync,
                  'asyncState': a.asyncState,
                })
            .toList(),
        'memoryInfo': {
          'trackedAtomCount': memoryInfo.trackedAtomCount,
          'registeredAtomCount': memoryInfo.registeredAtomCount,
          'orphanedAtomCount': memoryInfo.orphanedAtomCount,
        },
        'graph': {
          'nodeCount': graph.nodes.length,
          'edgeCount': graph.edges.length,
        },
        'asyncTimeline': {
          'eventCount': timeline.length,
        },
        'performance': {
          'totalAtoms': performance.totalAtoms,
          'totalUpdates': performance.totalUpdates,
          'totalRebuilds': performance.totalRebuilds,
          'hotAtomCount': performance.hotAtoms.length,
          'suspectedLeakCount': performance.suspectedLeaks.length,
        },
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(snapshot);
      await Clipboard.setData(ClipboardData(text: jsonStr));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Snapshot copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Polling intervals section
        Text(
          'Polling Intervals',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Control how frequently each panel fetches data from the running app.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        _IntervalSetting(
          label: 'Atom Inspector',
          icon: Icons.list_alt,
          current: widget.atomPollInterval,
          onChanged: widget.onAtomPollChanged,
        ),
        _IntervalSetting(
          label: 'Dependency Graph',
          icon: Icons.account_tree,
          current: widget.graphPollInterval,
          onChanged: widget.onGraphPollChanged,
        ),
        _IntervalSetting(
          label: 'Async Timeline',
          icon: Icons.timeline,
          current: widget.timelinePollInterval,
          onChanged: widget.onTimelinePollChanged,
        ),
        _IntervalSetting(
          label: 'Performance',
          icon: Icons.speed,
          current: widget.perfPollInterval,
          onChanged: widget.onPerfPollChanged,
        ),

        const SizedBox(height: 32),

        // Export section
        Text(
          'Export',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Export a JSON snapshot of all atom state, metrics, and diagnostics to the clipboard.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportSnapshot,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, size: 18),
            label: Text(_isExporting ? 'Exporting...' : 'Export Snapshot'),
          ),
        ),

        const SizedBox(height: 32),

        // About section
        Text(
          'About',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _AboutRow(label: 'Extension', value: 'AtomicFlutter DevTools v0.1.0'),
        _AboutRow(label: 'Package', value: 'atomic_flutter'),
        _AboutRow(
          label: 'Repository',
          value: 'github.com/arkarmintun1/atomic_flutter',
        ),
      ],
    );
  }
}

class _IntervalSetting extends StatelessWidget {
  final String label;
  final IconData icon;
  final Duration current;
  final ValueChanged<Duration> onChanged;

  const _IntervalSetting({
    required this.label,
    required this.icon,
    required this.current,
    required this.onChanged,
  });

  static const _options = [
    (label: '250ms', duration: Duration(milliseconds: 250)),
    (label: '500ms', duration: Duration(milliseconds: 500)),
    (label: '1s', duration: Duration(seconds: 1)),
    (label: '2s', duration: Duration(seconds: 2)),
    (label: '5s', duration: Duration(seconds: 5)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<Duration>(
            segments: _options
                .map((o) => ButtonSegment(
                      value: o.duration,
                      label:
                          Text(o.label, style: const TextStyle(fontSize: 11)),
                    ))
                .toList(),
            selected: {current},
            onSelectionChanged: (set) => onChanged(set.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
