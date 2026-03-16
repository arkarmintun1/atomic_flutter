import 'dart:ui';

/// A node in the atom dependency graph.
class GraphNode {
  final String id;
  final String type; // 'atom', 'computed', 'async'
  final String valueType;
  final int refCount;
  final int listenerCount;
  final int dependencyCount;
  final int dependentCount;

  // Layout position (computed by force-directed algorithm)
  double x;
  double y;
  double vx = 0;
  double vy = 0;

  // Selection state
  bool isHighlighted = false;
  bool isDimmed = false;

  GraphNode({
    required this.id,
    required this.type,
    required this.valueType,
    required this.refCount,
    required this.listenerCount,
    required this.dependencyCount,
    required this.dependentCount,
    this.x = 0,
    this.y = 0,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'atom',
      valueType: json['valueType'] as String? ?? '',
      refCount: json['refCount'] as int? ?? 0,
      listenerCount: json['listenerCount'] as int? ?? 0,
      dependencyCount: json['dependencyCount'] as int? ?? 0,
      dependentCount: json['dependentCount'] as int? ?? 0,
    );
  }

  Color get color => switch (type) {
        'computed' => const Color(0xFF4CAF50), // green
        'async' => const Color(0xFFFF9800), // orange
        _ => const Color(0xFF2196F3), // blue
      };

  String get displayLabel {
    if (id.length > 20) return '${id.substring(0, 17)}...';
    return id;
  }

  double get radius => 20.0 + (dependentCount * 2.0).clamp(0, 15);
}

/// An edge in the atom dependency graph.
class GraphEdge {
  final String from;
  final String to;
  final String type;

  const GraphEdge({
    required this.from,
    required this.to,
    required this.type,
  });

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      type: json['type'] as String? ?? 'dependency',
    );
  }
}

/// Complete graph data from the service layer.
class GraphData {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  const GraphData({required this.nodes, required this.edges});

  factory GraphData.fromJson(Map<String, dynamic> json) {
    final nodesList = json['nodes'] as List<dynamic>? ?? [];
    final edgesList = json['edges'] as List<dynamic>? ?? [];

    return GraphData(
      nodes: nodesList
          .map((e) => GraphNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      edges: edgesList
          .map((e) => GraphEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isEmpty => nodes.isEmpty;
}
