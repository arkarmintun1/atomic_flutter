import 'package:atomic_flutter_devtools_extension/src/models/models.dart';
import 'package:flutter/material.dart';

/// Sortable table of all registered atoms.
class AtomTable extends StatefulWidget {
  final List<AtomData> atoms;
  final String? selectedAtomId;
  final ValueChanged<String> onAtomSelected;

  const AtomTable({
    super.key,
    required this.atoms,
    this.selectedAtomId,
    required this.onAtomSelected,
  });

  @override
  State<AtomTable> createState() => _AtomTableState();
}

enum _SortColumn { id, type, value, refCount, status }

class _AtomTableState extends State<AtomTable> {
  _SortColumn _sortColumn = _SortColumn.id;
  bool _sortAscending = true;

  List<AtomData> get _sortedAtoms {
    final sorted = List<AtomData>.from(widget.atoms);
    sorted.sort((a, b) {
      int result;
      switch (_sortColumn) {
        case _SortColumn.id:
          result = a.id.compareTo(b.id);
        case _SortColumn.type:
          result = a.type.compareTo(b.type);
        case _SortColumn.value:
          result = a.value.compareTo(b.value);
        case _SortColumn.refCount:
          result = a.refCount.compareTo(b.refCount);
        case _SortColumn.status:
          result = a.statusLabel.compareTo(b.statusLabel);
      }
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  void _onSort(_SortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = _sortedAtoms;

    return Column(
      children: [
        // Header row
        _buildHeaderRow(theme),
        const Divider(height: 1),
        // Data rows
        Expanded(
          child: ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final atom = sorted[index];
              final isSelected = atom.id == widget.selectedAtomId;
              return _buildDataRow(theme, atom, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _HeaderCell(
            label: 'ID',
            flex: 3,
            sorted: _sortColumn == _SortColumn.id,
            ascending: _sortAscending,
            onTap: () => _onSort(_SortColumn.id),
          ),
          _HeaderCell(
            label: 'Type',
            flex: 2,
            sorted: _sortColumn == _SortColumn.type,
            ascending: _sortAscending,
            onTap: () => _onSort(_SortColumn.type),
          ),
          _HeaderCell(
            label: 'Value',
            flex: 4,
            sorted: _sortColumn == _SortColumn.value,
            ascending: _sortAscending,
            onTap: () => _onSort(_SortColumn.value),
          ),
          _HeaderCell(
            label: 'Refs',
            flex: 1,
            sorted: _sortColumn == _SortColumn.refCount,
            ascending: _sortAscending,
            onTap: () => _onSort(_SortColumn.refCount),
          ),
          _HeaderCell(
            label: 'Status',
            flex: 2,
            sorted: _sortColumn == _SortColumn.status,
            ascending: _sortAscending,
            onTap: () => _onSort(_SortColumn.status),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(ThemeData theme, AtomData atom, bool isSelected) {
    return InkWell(
      onTap: () => widget.onAtomSelected(atom.id),
      child: Container(
        color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // ID
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _atomIcon(atom, theme),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      atom.id,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Type
            Expanded(
              flex: 2,
              child: Text(
                atom.type,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Value
            Expanded(
              flex: 4,
              child: Text(
                atom.displayValue,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Ref count
            Expanded(
              flex: 1,
              child: Text(
                '${atom.refCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: atom.refCount == 0
                      ? Colors.orange
                      : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Status
            Expanded(
              flex: 2,
              child: _StatusBadge(atom: atom),
            ),
          ],
        ),
      ),
    );
  }

  Widget _atomIcon(AtomData atom, ThemeData theme) {
    if (atom.isAsync) {
      return Icon(Icons.sync, size: 14, color: Colors.orange[600]);
    }
    return Icon(Icons.blur_circular,
        size: 14, color: theme.colorScheme.primary);
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool sorted;
  final bool ascending;
  final VoidCallback onTap;

  const _HeaderCell({
    required this.label,
    required this.flex,
    required this.sorted,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: sorted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (sorted)
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AtomData atom;

  const _StatusBadge({required this.atom});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _getStatusInfo();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
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

  (String, Color) _getStatusInfo() {
    if (atom.isAsync) {
      return switch (atom.asyncState) {
        'idle' => ('idle', Colors.grey),
        'loading' => ('loading', Colors.blue),
        'success' => ('success', Colors.green),
        'error' => ('error', Colors.red),
        _ => (atom.asyncState ?? 'unknown', Colors.grey),
      };
    }

    if (!atom.hasListeners) {
      return ('unused', Colors.orange);
    }

    if (atom.autoDispose) {
      return ('active', Colors.green);
    }

    return ('persistent', Colors.blue);
  }
}
