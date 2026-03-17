import 'dart:async';

import 'package:atomic_flutter_devtools_extension/src/models/models.dart';
import 'package:atomic_flutter_devtools_extension/src/services/atom_service_client.dart';
import 'package:flutter/material.dart';

/// Performance dashboard showing update rates, rebuild counts,
/// hot atom warnings, and suspected memory leaks.
class PerformancePanel extends StatefulWidget {
  const PerformancePanel({super.key});

  @override
  State<PerformancePanel> createState() => _PerformancePanelState();
}

class _PerformancePanelState extends State<PerformancePanel> {
  PerformanceSummaryData _data = PerformanceSummaryData.empty;
  bool _isLoading = true;
  Timer? _pollTimer;

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
      final data = await AtomServiceClient.getPerformanceSummary();
      if (!mounted) return;
      setState(() {
        _data = data;
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

    return Column(
      children: [
        _buildSummaryBar(context),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Hot atoms section
              if (_data.hotAtoms.isNotEmpty) ...[
                _buildSectionHeader(
                    context, 'Hot Atoms', Icons.whatshot, Colors.orange),
                const SizedBox(height: 8),
                ..._data.hotAtoms.map((h) => _HotAtomCard(data: h)),
                const SizedBox(height: 20),
              ],

              // Suspected leaks section
              if (_data.suspectedLeaks.isNotEmpty) ...[
                _buildSectionHeader(context, 'Suspected Memory Leaks',
                    Icons.memory, Colors.red),
                const SizedBox(height: 8),
                ..._data.suspectedLeaks.map((l) => _LeakCard(data: l)),
                const SizedBox(height: 20),
              ],

              // Update frequency ranking
              _buildSectionHeader(
                  context, 'Update Frequency', Icons.update, Colors.blue),
              const SizedBox(height: 8),
              _buildUpdateTable(context),
              const SizedBox(height: 20),

              // Rebuild count ranking
              if (_data.rebuildCounts.isNotEmpty) ...[
                _buildSectionHeader(context, 'Widget Rebuild Counts',
                    Icons.refresh, Colors.green),
                const SizedBox(height: 8),
                _buildRebuildTable(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _SummaryTile(
            icon: Icons.blur_circular,
            value: '${_data.totalAtoms}',
            label: 'Atoms',
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 24),
          _SummaryTile(
            icon: Icons.update,
            value: '${_data.totalUpdates}',
            label: 'Updates',
            color: Colors.blue,
          ),
          const SizedBox(width: 24),
          _SummaryTile(
            icon: Icons.refresh,
            value: '${_data.totalRebuilds}',
            label: 'Rebuilds',
            color: Colors.green,
          ),
          const SizedBox(width: 24),
          if (_data.hotAtoms.isNotEmpty)
            _SummaryTile(
              icon: Icons.whatshot,
              value: '${_data.hotAtoms.length}',
              label: 'Hot',
              color: Colors.orange,
            ),
          if (_data.suspectedLeaks.isNotEmpty) ...[
            const SizedBox(width: 24),
            _SummaryTile(
              icon: Icons.memory,
              value: '${_data.suspectedLeaks.length}',
              label: 'Leaks',
              color: Colors.red,
            ),
          ],
          const Spacer(),
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

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildUpdateTable(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = List<UpdateMetricData>.from(_data.updateMetrics)
      ..sort((a, b) => b.updateCount.compareTo(a.updateCount));

    if (sorted.isEmpty) {
      return Text(
        'No update metrics recorded yet. Enable performance monitoring.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      );
    }

    final maxCount =
        sorted.first.updateCount > 0 ? sorted.first.updateCount : 1;

    return Column(
      children: sorted.map((m) {
        return _MetricRow(
          atomId: m.atomId,
          value: m.updateCount,
          maxValue: maxCount,
          suffix: 'updates',
          subtext: m.avgIntervalMs > 0 ? 'avg ${m.avgIntervalMs}ms' : null,
          color: Colors.blue,
        );
      }).toList(),
    );
  }

  Widget _buildRebuildTable(BuildContext context) {
    final sorted = List<RebuildCountData>.from(_data.rebuildCounts)
      ..sort((a, b) => b.rebuildCount.compareTo(a.rebuildCount));

    final maxCount =
        sorted.first.rebuildCount > 0 ? sorted.first.rebuildCount : 1;

    return Column(
      children: sorted.map((r) {
        return _MetricRow(
          atomId: r.atomId,
          value: r.rebuildCount,
          maxValue: maxCount,
          suffix: 'rebuilds',
          color: Colors.green,
        );
      }).toList(),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String atomId;
  final int value;
  final int maxValue;
  final String suffix;
  final String? subtext;
  final Color color;

  const _MetricRow({
    required this.atomId,
    required this.value,
    required this.maxValue,
    required this.suffix,
    this.subtext,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.02, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              atomId,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 16,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$value $suffix',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                if (subtext != null)
                  Text(
                    subtext!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HotAtomCard extends StatelessWidget {
  final HotAtomData data;

  const _HotAtomCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.orange.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.whatshot, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.atomId,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(
                    label: '${data.updateCount} updates', color: Colors.blue),
                const SizedBox(width: 8),
                _StatChip(
                    label: '${data.rebuildCount} rebuilds',
                    color: Colors.green),
                const SizedBox(width: 8),
                _StatChip(
                    label: '${data.listenerCount} listeners',
                    color: Colors.purple),
              ],
            ),
            const SizedBox(height: 8),
            ...data.warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 12, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(w,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.orange[800])),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _LeakCard extends StatelessWidget {
  final SuspectedLeakData data;

  const _LeakCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.red.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.memory, size: 16, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.atomId,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10,
            ),
      ),
    );
  }
}
