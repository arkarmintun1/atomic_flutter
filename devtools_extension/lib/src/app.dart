import 'package:flutter/material.dart';

import 'async_timeline/async_timeline_panel.dart';
import 'atom_inspector/atom_inspector_panel.dart';
import 'dependency_graph/dependency_graph_panel.dart';
import 'performance/performance_panel.dart';
import 'settings/settings_panel.dart';

/// Root widget for the AtomicFlutter DevTools extension.
class AtomicFlutterApp extends StatefulWidget {
  const AtomicFlutterApp({super.key});

  @override
  State<AtomicFlutterApp> createState() => _AtomicFlutterAppState();
}

class _AtomicFlutterAppState extends State<AtomicFlutterApp> {
  int _selectedTab = 0;

  // Configurable polling intervals
  Duration _atomPollInterval = const Duration(milliseconds: 500);
  Duration _graphPollInterval = const Duration(seconds: 2);
  Duration _timelinePollInterval = const Duration(seconds: 1);
  Duration _perfPollInterval = const Duration(seconds: 1);

  // Key-based rebuild to restart polling when interval changes
  int _atomPollKey = 0;
  int _graphPollKey = 0;
  int _timelinePollKey = 0;
  int _perfPollKey = 0;

  static const _tabs = [
    _TabInfo(label: 'Atom Inspector', icon: Icons.list_alt),
    _TabInfo(label: 'Dependencies', icon: Icons.account_tree),
    _TabInfo(label: 'Async Timeline', icon: Icons.timeline),
    _TabInfo(label: 'Performance', icon: Icons.speed),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(context),
        const Divider(height: 1),
        Expanded(
          child: _buildSelectedPanel(),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          for (int i = 0; i < _tabs.length; i++) ...[
            _TabButton(
              label: _tabs[i].label,
              icon: _tabs[i].icon,
              isSelected: _selectedTab == i,
              onTap: () => setState(() => _selectedTab = i),
            ),
            const SizedBox(width: 4),
          ],
          const Spacer(),
          // Settings gear icon
          IconButton(
            icon: Icon(
              Icons.settings,
              size: 18,
              color: _selectedTab == 4
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            tooltip: 'Settings',
            onPressed: () => setState(() => _selectedTab = 4),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSelectedPanel() {
    switch (_selectedTab) {
      case 0:
        return AtomInspectorPanel(key: ValueKey('atom_$_atomPollKey'));
      case 1:
        return DependencyGraphPanel(key: ValueKey('graph_$_graphPollKey'));
      case 2:
        return AsyncTimelinePanel(key: ValueKey('timeline_$_timelinePollKey'));
      case 3:
        return PerformancePanel(key: ValueKey('perf_$_perfPollKey'));
      case 4:
        return SettingsPanel(
          atomPollInterval: _atomPollInterval,
          graphPollInterval: _graphPollInterval,
          timelinePollInterval: _timelinePollInterval,
          perfPollInterval: _perfPollInterval,
          onAtomPollChanged: (d) => setState(() {
            _atomPollInterval = d;
            _atomPollKey++;
          }),
          onGraphPollChanged: (d) => setState(() {
            _graphPollInterval = d;
            _graphPollKey++;
          }),
          onTimelinePollChanged: (d) => setState(() {
            _timelinePollInterval = d;
            _timelinePollKey++;
          }),
          onPerfPollChanged: (d) => setState(() {
            _perfPollInterval = d;
            _perfPollKey++;
          }),
        );
      default:
        return const Center(child: Text('Coming soon'));
    }
  }
}

class _TabInfo {
  final String label;
  final IconData icon;

  const _TabInfo({required this.label, required this.icon});
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: isSelected
              ? Border(
                  bottom:
                      BorderSide(color: theme.colorScheme.primary, width: 2),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
