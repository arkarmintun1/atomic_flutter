import 'dart:async';

import 'package:atomic_flutter_devtools_extension/src/atom_inspector/atom_detail_view.dart';
import 'package:atomic_flutter_devtools_extension/src/atom_inspector/atom_table.dart';
import 'package:atomic_flutter_devtools_extension/src/models/models.dart';
import 'package:atomic_flutter_devtools_extension/src/services/atom_service_client.dart';
import 'package:flutter/material.dart';

/// The Atom Inspector panel — shows a live table of all registered atoms
/// with search/filter and a detail pane for the selected atom.
class AtomInspectorPanel extends StatefulWidget {
  const AtomInspectorPanel({super.key});

  @override
  State<AtomInspectorPanel> createState() => _AtomInspectorPanelState();
}

class _AtomInspectorPanelState extends State<AtomInspectorPanel> {
  List<AtomData> _atoms = [];
  MemoryInfoData _memoryInfo = const MemoryInfoData(
    trackedAtomCount: 0,
    registeredAtomCount: 0,
    orphanedAtomCount: 0,
  );
  AtomDetailData? _selectedDetail;
  String? _selectedAtomId;
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    try {
      final atoms = await AtomServiceClient.getAtoms();
      final memoryInfo = await AtomServiceClient.getMemoryInfo();

      if (!mounted) return;

      setState(() {
        _atoms = atoms;
        _memoryInfo = memoryInfo;
        _isLoading = false;
        _error = null;
      });

      // Refresh selected atom detail if one is selected
      if (_selectedAtomId != null) {
        final detail = await AtomServiceClient.getAtomDetail(_selectedAtomId!);
        if (mounted) {
          setState(() => _selectedDetail = detail);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<AtomData> get _filteredAtoms {
    if (_searchQuery.isEmpty) return _atoms;
    final query = _searchQuery.toLowerCase();
    return _atoms.where((atom) {
      return atom.id.toLowerCase().contains(query) ||
          atom.type.toLowerCase().contains(query) ||
          atom.value.toLowerCase().contains(query);
    }).toList();
  }

  void _onAtomSelected(String atomId) {
    setState(() => _selectedAtomId = atomId);
    // Fetch detail immediately
    AtomServiceClient.getAtomDetail(atomId).then((detail) {
      if (mounted) {
        setState(() => _selectedDetail = detail);
      }
    });
  }

  void _onDetailClosed() {
    setState(() {
      _selectedAtomId = null;
      _selectedDetail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_atoms.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildToolbar(context),
        const Divider(height: 1),
        Expanded(
          child: _selectedDetail != null
              ? Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AtomTable(
                        atoms: _filteredAtoms,
                        selectedAtomId: _selectedAtomId,
                        onAtomSelected: _onAtomSelected,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: AtomDetailView(
                        detail: _selectedDetail!,
                        onClose: _onDetailClosed,
                      ),
                    ),
                  ],
                )
              : AtomTable(
                  atoms: _filteredAtoms,
                  selectedAtomId: _selectedAtomId,
                  onAtomSelected: _onAtomSelected,
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Filter atoms by ID, type, or value...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Summary chips
          _SummaryChip(
            icon: Icons.blur_circular,
            label: '${_memoryInfo.registeredAtomCount} atoms',
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          if (_memoryInfo.orphanedAtomCount > 0) ...[
            _SummaryChip(
              icon: Icons.warning_amber,
              label: '${_memoryInfo.orphanedAtomCount} orphaned',
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
          ],
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh now',
            onPressed: _fetchData,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.blur_circular, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No atoms registered',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your app calls enableDebugMode() before creating atoms.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Failed to connect',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
