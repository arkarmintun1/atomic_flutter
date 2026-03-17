import 'dart:math';

import 'package:atomic_flutter_devtools_extension/src/models/models.dart';
import 'package:flutter/material.dart';

/// Paints the dependency graph on a Canvas.
class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String? hoveredNodeId;

  GraphPainter({
    required this.nodes,
    required this.edges,
    this.hoveredNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    final nodeMap = {for (final n in nodes) n.id: n};

    // Draw edges first (behind nodes)
    for (final edge in edges) {
      final from = nodeMap[edge.from];
      final to = nodeMap[edge.to];
      if (from == null || to == null) continue;

      final isHighlighted = !from.isDimmed && !to.isDimmed;

      _drawEdge(canvas, from, to, isHighlighted);
    }

    // Draw nodes on top
    for (final node in nodes) {
      _drawNode(canvas, node);
    }
  }

  void _drawEdge(
      Canvas canvas, GraphNode from, GraphNode to, bool isHighlighted) {
    final paint = Paint()
      ..color = isHighlighted ? Colors.grey.shade600 : Colors.grey.shade300
      ..strokeWidth = isHighlighted ? 1.5 : 0.8
      ..style = PaintingStyle.stroke;

    final fromOffset = Offset(from.x, from.y);
    final toOffset = Offset(to.x, to.y);

    // Shorten line to end at node border (not center)
    final dx = toOffset.dx - fromOffset.dx;
    final dy = toOffset.dy - fromOffset.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 1) return;

    final unitX = dx / dist;
    final unitY = dy / dist;

    final start = Offset(
      fromOffset.dx + unitX * from.radius,
      fromOffset.dy + unitY * from.radius,
    );
    final end = Offset(
      toOffset.dx - unitX * to.radius,
      toOffset.dy - unitY * to.radius,
    );

    canvas.drawLine(start, end, paint);

    // Draw arrowhead
    _drawArrowHead(canvas, start, end, paint, isHighlighted);
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint linePaint,
    bool isHighlighted,
  ) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final angle = atan2(dy, dx);

    const arrowLength = 10.0;
    const arrowAngle = 0.5; // ~28 degrees

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - arrowLength * cos(angle - arrowAngle),
        to.dy - arrowLength * sin(angle - arrowAngle),
      )
      ..lineTo(
        to.dx - arrowLength * cos(angle + arrowAngle),
        to.dy - arrowLength * sin(angle + arrowAngle),
      )
      ..close();

    final fillPaint = Paint()
      ..color = isHighlighted ? Colors.grey.shade600 : Colors.grey.shade300
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
  }

  void _drawNode(Canvas canvas, GraphNode node) {
    final center = Offset(node.x, node.y);
    final isHovered = node.id == hoveredNodeId;

    // Shadow
    if (isHovered || node.isHighlighted) {
      final shadowPaint = Paint()
        ..color = node.color.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, node.radius + 4, shadowPaint);
    }

    // Node circle
    final fillPaint = Paint()
      ..color = node.isDimmed
          ? node.color.withValues(alpha: 0.2)
          : node.color.withValues(alpha: isHovered ? 1.0 : 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, node.radius, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = node.isDimmed
          ? Colors.grey.shade300
          : (isHovered || node.isHighlighted)
              ? node.color
              : node.color.withValues(alpha: 0.6)
      ..strokeWidth = (isHovered || node.isHighlighted) ? 2.5 : 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, node.radius, borderPaint);

    // Label
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.displayLabel,
        style: TextStyle(
          color: node.isDimmed ? Colors.grey.shade400 : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: node.radius * 2.5);

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy + node.radius + 6,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return true; // Always repaint during interaction
  }
}
