import 'dart:async';

import 'package:atomic_flutter_devtools_extension/src/dependency_graph/graph_painter.dart';
import 'package:atomic_flutter_devtools_extension/src/dependency_graph/layout_algorithm.dart';
import 'package:atomic_flutter_devtools_extension/src/models/models.dart';
import 'package:atomic_flutter_devtools_extension/src/services/atom_service_client.dart';
import 'package:flutter/material.dart';

/// Interactive dependency graph visualization.
///
/// Shows atoms as nodes and dependency relationships as directed edges.
/// Click a node to highlight its upstream/downstream chain.
class DependencyGraphPanel extends StatefulWidget {
  const DependencyGraphPanel({super.key});

  @override
  State<DependencyGraphPanel> createState() => _DependencyGraphPanelState();
}

class _DependencyGraphPanelState extends State<DependencyGraphPanel> {
  GraphData _graphData = const GraphData(nodes: [], edges: []);
  bool _isLoading = true;
  String? _selectedNodeId;
  String? _hoveredNodeId;
  Timer? _pollTimer;
  final _layout = const ForceDirectedLayout();
  bool _needsLayout = true;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
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
      final data = await AtomServiceClient.getDependencyGraph();
      if (!mounted) return;

      // Check if the graph structure actually changed (different node IDs or edges)
      final oldNodeIds = _graphData.nodes.map((n) => n.id).toSet();
      final newNodeIds = data.nodes.map((n) => n.id).toSet();
      final oldEdgeKeys =
          _graphData.edges.map((e) => '${e.from}->${e.to}').toSet();
      final newEdgeKeys = data.edges.map((e) => '${e.from}->${e.to}').toSet();

      final structureChanged = !_setEquals(oldNodeIds, newNodeIds) ||
          !_setEquals(oldEdgeKeys, newEdgeKeys);

      if (structureChanged) {
        // Structure changed — carry over positions for nodes that still exist
        final oldPositions = <String, (double, double)>{};
        for (final node in _graphData.nodes) {
          oldPositions[node.id] = (node.x, node.y);
        }
        for (final node in data.nodes) {
          final pos = oldPositions[node.id];
          if (pos != null) {
            node.x = pos.$1;
            node.y = pos.$2;
          }
        }

        setState(() {
          _graphData = data;
          _isLoading = false;
          // Only need full re-layout if new nodes were added
          _needsLayout = !newNodeIds.every(oldNodeIds.contains);
        });
      } else {
        // Same structure — just update metadata, keep positions
        final oldPositions = <String, (double, double, double, double)>{};
        for (final node in _graphData.nodes) {
          oldPositions[node.id] = (node.x, node.y, node.vx, node.vy);
        }
        for (final node in data.nodes) {
          final pos = oldPositions[node.id];
          if (pos != null) {
            node.x = pos.$1;
            node.y = pos.$2;
            node.vx = pos.$3;
            node.vy = pos.$4;
          }
        }

        // Preserve highlight state
        if (_selectedNodeId != null) {
          _applyHighlightChain(data, _selectedNodeId!);
        }

        setState(() {
          _graphData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    return a.length == b.length && a.every(b.contains);
  }

  void _applyHighlightChain(GraphData data, String nodeId) {
    final connected = <String>{nodeId};

    void walkUp(String id) {
      for (final edge in data.edges) {
        if (edge.to == id && !connected.contains(edge.from)) {
          connected.add(edge.from);
          walkUp(edge.from);
        }
      }
    }

    void walkDown(String id) {
      for (final edge in data.edges) {
        if (edge.from == id && !connected.contains(edge.to)) {
          connected.add(edge.to);
          walkDown(edge.to);
        }
      }
    }

    walkUp(nodeId);
    walkDown(nodeId);

    for (final node in data.nodes) {
      node.isHighlighted = node.id == nodeId;
      node.isDimmed = !connected.contains(node.id);
    }
  }

  void _onNodeTapped(String nodeId) {
    setState(() {
      if (_selectedNodeId == nodeId) {
        // Deselect
        _selectedNodeId = null;
        for (final node in _graphData.nodes) {
          node.isHighlighted = false;
          node.isDimmed = false;
        }
      } else {
        // Select and highlight chain
        _selectedNodeId = nodeId;
        _highlightChain(nodeId);
      }
    });
  }

  void _highlightChain(String nodeId) {
    // Find all connected nodes (upstream and downstream)
    final connected = <String>{nodeId};

    // Walk upstream (dependencies of the selected node)
    void walkUp(String id) {
      for (final edge in _graphData.edges) {
        if (edge.to == id && !connected.contains(edge.from)) {
          connected.add(edge.from);
          walkUp(edge.from);
        }
      }
    }

    // Walk downstream (dependents of the selected node)
    void walkDown(String id) {
      for (final edge in _graphData.edges) {
        if (edge.from == id && !connected.contains(edge.to)) {
          connected.add(edge.to);
          walkDown(edge.to);
        }
      }
    }

    walkUp(nodeId);
    walkDown(nodeId);

    for (final node in _graphData.nodes) {
      node.isHighlighted = node.id == nodeId;
      node.isDimmed = !connected.contains(node.id);
    }
  }

  String? _hitTestNode(Offset position) {
    for (final node in _graphData.nodes) {
      final dx = position.dx - node.x;
      final dy = position.dy - node.y;
      if (dx * dx + dy * dy <= node.radius * node.radius) {
        return node.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_graphData.isEmpty) {
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );

                    if (_needsLayout || size != _lastSize) {
                      _layout.run(
                        _graphData.nodes,
                        _graphData.edges,
                        size.width,
                        size.height,
                      );
                      _needsLayout = false;
                      _lastSize = size;
                    }

                    return MouseRegion(
                      onHover: (event) {
                        final hit = _hitTestNode(event.localPosition);
                        if (hit != _hoveredNodeId) {
                          setState(() => _hoveredNodeId = hit);
                        }
                      },
                      onExit: (_) {
                        if (_hoveredNodeId != null) {
                          setState(() => _hoveredNodeId = null);
                        }
                      },
                      cursor: _hoveredNodeId != null
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: GestureDetector(
                        onTapDown: (details) {
                          final hit = _hitTestNode(details.localPosition);
                          if (hit != null) {
                            _onNodeTapped(hit);
                          } else if (_selectedNodeId != null) {
                            // Tap on empty space deselects
                            _onNodeTapped(_selectedNodeId!);
                          }
                        },
                        child: CustomPaint(
                          size: size,
                          painter: GraphPainter(
                            nodes: _graphData.nodes,
                            edges: _graphData.edges,
                            hoveredNodeId: _hoveredNodeId,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_selectedNodeId != null) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 220,
                  child: _buildNodeDetail(context),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _LegendDot(color: const Color(0xFF2196F3), label: 'Atom'),
          const SizedBox(width: 12),
          _LegendDot(color: const Color(0xFF4CAF50), label: 'Computed'),
          const SizedBox(width: 12),
          _LegendDot(color: const Color(0xFFFF9800), label: 'Async'),
          const Spacer(),
          Text(
            '${_graphData.nodes.length} nodes, ${_graphData.edges.length} edges',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Re-layout',
            onPressed: () {
              setState(() => _needsLayout = true);
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildNodeDetail(BuildContext context) {
    final theme = Theme.of(context);
    final node =
        _graphData.nodes.where((n) => n.id == _selectedNodeId).firstOrNull;

    if (node == null) return const SizedBox.shrink();

    final upstream = _graphData.edges
        .where((e) => e.to == node.id)
        .map((e) => e.from)
        .toList();
    final downstream = _graphData.edges
        .where((e) => e.from == node.id)
        .map((e) => e.to)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: node.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.id,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DetailRow(label: 'Type', value: node.type),
        _DetailRow(label: 'Value Type', value: node.valueType),
        _DetailRow(label: 'Refs', value: '${node.refCount}'),
        _DetailRow(label: 'Listeners', value: '${node.listenerCount}'),
        if (upstream.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Depends on',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final id in upstream)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                onTap: () => _onNodeTapped(id),
                child: Text(
                  id,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
        if (downstream.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Depended on by',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final id in downstream)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                onTap: () => _onNodeTapped(id),
                child: Text(
                  id,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No dependencies found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create computed atoms with tracked dependencies to see the graph.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
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
