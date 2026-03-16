import 'dart:math';

import 'package:atomic_flutter_devtools_extension/src/models/models.dart';

/// Simple force-directed layout for the dependency graph.
///
/// Uses a spring-electric model:
/// - Edges act as springs pulling connected nodes together
/// - All nodes repel each other to avoid overlap
/// - Gravity pulls nodes toward the center
class ForceDirectedLayout {
  final double repulsionForce;
  final double attractionForce;
  final double gravity;
  final double damping;

  const ForceDirectedLayout({
    this.repulsionForce = 5000,
    this.attractionForce = 0.01,
    this.gravity = 0.02,
    this.damping = 0.85,
  });

  /// Initialize node positions in a circle.
  void initializePositions(List<GraphNode> nodes, double width, double height) {
    final cx = width / 2;
    final cy = height / 2;
    final radius = min(width, height) * 0.35;

    for (int i = 0; i < nodes.length; i++) {
      final angle = (2 * pi * i) / nodes.length;
      nodes[i].x = cx + radius * cos(angle);
      nodes[i].y = cy + radius * sin(angle);
      nodes[i].vx = 0;
      nodes[i].vy = 0;
    }
  }

  /// Run one iteration of the force simulation.
  /// Returns the total kinetic energy (use to detect convergence).
  double step(
    List<GraphNode> nodes,
    List<GraphEdge> edges,
    double width,
    double height,
  ) {
    final cx = width / 2;
    final cy = height / 2;

    // Reset forces
    final fx = List.filled(nodes.length, 0.0);
    final fy = List.filled(nodes.length, 0.0);

    final nodeIndex = <String, int>{};
    for (int i = 0; i < nodes.length; i++) {
      nodeIndex[nodes[i].id] = i;
    }

    // Repulsion between all node pairs
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        var dx = nodes[j].x - nodes[i].x;
        var dy = nodes[j].y - nodes[i].y;
        var dist = sqrt(dx * dx + dy * dy);
        if (dist < 1) dist = 1;

        final force = repulsionForce / (dist * dist);
        final forceX = force * dx / dist;
        final forceY = force * dy / dist;

        fx[i] -= forceX;
        fy[i] -= forceY;
        fx[j] += forceX;
        fy[j] += forceY;
      }
    }

    // Attraction along edges
    for (final edge in edges) {
      final fromIdx = nodeIndex[edge.from];
      final toIdx = nodeIndex[edge.to];
      if (fromIdx == null || toIdx == null) continue;

      final dx = nodes[toIdx].x - nodes[fromIdx].x;
      final dy = nodes[toIdx].y - nodes[fromIdx].y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 1) continue;

      final force = attractionForce * dist;
      final forceX = force * dx / dist;
      final forceY = force * dy / dist;

      fx[fromIdx] += forceX;
      fy[fromIdx] += forceY;
      fx[toIdx] -= forceX;
      fy[toIdx] -= forceY;
    }

    // Gravity toward center
    for (int i = 0; i < nodes.length; i++) {
      fx[i] += (cx - nodes[i].x) * gravity;
      fy[i] += (cy - nodes[i].y) * gravity;
    }

    // Apply forces with damping
    double totalEnergy = 0;
    for (int i = 0; i < nodes.length; i++) {
      nodes[i].vx = (nodes[i].vx + fx[i]) * damping;
      nodes[i].vy = (nodes[i].vy + fy[i]) * damping;
      nodes[i].x += nodes[i].vx;
      nodes[i].y += nodes[i].vy;

      // Keep in bounds with padding
      const padding = 40.0;
      nodes[i].x = nodes[i].x.clamp(padding, width - padding);
      nodes[i].y = nodes[i].y.clamp(padding, height - padding);

      totalEnergy += nodes[i].vx * nodes[i].vx + nodes[i].vy * nodes[i].vy;
    }

    return totalEnergy;
  }

  /// Run the simulation until it converges or hits max iterations.
  void run(
    List<GraphNode> nodes,
    List<GraphEdge> edges,
    double width,
    double height, {
    int maxIterations = 150,
    double convergenceThreshold = 0.5,
  }) {
    initializePositions(nodes, width, height);

    for (int i = 0; i < maxIterations; i++) {
      final energy = step(nodes, edges, width, height);
      if (energy < convergenceThreshold) break;
    }
  }
}
