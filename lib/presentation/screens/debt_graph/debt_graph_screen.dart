import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';

// ---------- Data Model ----------

class _Node {
  final int userId;
  final String name;
  final double netBalance;
  Offset position;

  _Node(this.userId, this.name, this.netBalance, this.position);
}

class _Edge {
  final int fromId;
  final int toId;
  final double amount;
  final bool isTransitive; // curved jump line (A→B→C → A dashes to C)

  _Edge(this.fromId, this.toId, this.amount, {this.isTransitive = false});
}

// ---------- Graph Screen ----------

class DebtGraphScreen extends StatefulWidget {
  const DebtGraphScreen({super.key});

  @override
  State<DebtGraphScreen> createState() => _DebtGraphScreenState();
}

class _DebtGraphScreenState extends State<DebtGraphScreen> {
  final Map<int, _Node> _nodes = {};
  List<_Edge> _directEdges = [];
  List<_Edge> _transitiveEdges = [];
  int? _selectedNodeId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildGraph();
  }

  void _buildGraph() {
    final balanceProvider = context.read<BalanceProvider>();
    final userProvider = context.read<UserProvider>();
    final netBalances = balanceProvider.balances;

    _nodes.clear();
    _directEdges = [];
    _transitiveEdges = [];

    if (netBalances.isEmpty) return;

    final userIds = netBalances.keys.toList();
    final n = userIds.length;

    // Layout nodes in a circle
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = (size.height - kToolbarHeight - MediaQuery.of(context).padding.top) / 2;
    final radius = min(cx, cy) * 0.65;

    for (int i = 0; i < n; i++) {
      final uid = userIds[i];
      final angle = (2 * pi * i / n) - pi / 2;
      final pos = Offset(cx + radius * cos(angle), cy + radius * sin(angle));
      final user = userProvider.getUserById(uid);
      if (user != null) {
        _nodes[uid] = _Node(uid, user.name, netBalances[uid] ?? 0, pos);
      }
    }

    // Direct edges from DebtSimplifier
    final transactions = DebtSimplifier().simplifyDebts(netBalances);
    _directEdges = transactions
        .map((tx) => _Edge(tx.fromUserId, tx.toUserId, tx.amount))
        .toList();

    // Compute transitive chains: if A→B and B→C, add curved A→C
    final directPairs = <(int, int)>{};
    for (final e in _directEdges) {
      directPairs.add((e.fromId, e.toId));
    }

    final Map<int, List<_Edge>> outgoing = {};
    for (final e in _directEdges) {
      outgoing.putIfAbsent(e.fromId, () => []).add(e);
    }

    final Set<(int, int)> transitiveAdded = {};
    for (final e1 in _directEdges) {
      final nexts = outgoing[e1.toId] ?? [];
      for (final e2 in nexts) {
        final pair = (e1.fromId, e2.toId);
        if (!transitiveAdded.contains(pair) && !directPairs.contains(pair)) {
          final amount = min(e1.amount, e2.amount);
          _transitiveEdges.add(_Edge(e1.fromId, e2.toId, amount, isTransitive: true));
          transitiveAdded.add(pair);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Debt Graph', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedNodeId != null)
            TextButton(
              onPressed: () => setState(() => _selectedNodeId = null),
              child: const Text('Clear', style: TextStyle(color: Colors.white60)),
            ),
        ],
      ),
      body: _nodes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text('All settled up!', style: tt.titleMedium?.copyWith(color: Colors.white38)),
                ],
              ),
            )
          : Stack(
              children: [
                // Canvas for edges
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ERGraphPainter(
                      nodes: _nodes,
                      directEdges: _directEdges,
                      transitiveEdges: _transitiveEdges,
                      selectedNodeId: _selectedNodeId,
                    ),
                  ),
                ),

                // Node widgets (draggable)
                ..._nodes.values.map((node) => _buildNode(node, cs, tt)),

                // Legend
                Positioned(
                  bottom: 24,
                  left: 16,
                  child: _buildLegend(tt),
                ),

                // Selection detail card
                if (_selectedNodeId != null) _buildDetailCard(cs, tt),
              ],
            ),
    );
  }

  Widget _buildNode(_Node node, ColorScheme cs, TextTheme tt) {
    final isSelected = _selectedNodeId == node.userId;

    final isHighlighted = _selectedNodeId == null ||
        _selectedNodeId == node.userId ||
        _directEdges.any((e) => (e.fromId == _selectedNodeId && e.toId == node.userId) ||
            (e.toId == _selectedNodeId && e.fromId == node.userId)) ||
        _transitiveEdges.any((e) => (e.fromId == _selectedNodeId && e.toId == node.userId) ||
            (e.toId == _selectedNodeId && e.fromId == node.userId));

    Color ringColor;
    if (node.netBalance > 0.01) {
      ringColor = const Color(0xFF22C55E); // green — is owed money
    } else if (node.netBalance < -0.01) {
      ringColor = const Color(0xFFEF4444); // red — owes money
    } else {
      ringColor = Colors.white38; // settled
    }

    return Positioned(
      left: node.position.dx - 36,
      top: node.position.dy - 36,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedNodeId = _selectedNodeId == node.userId ? null : node.userId;
        }),
        onPanUpdate: (d) => setState(() {
          node.position += d.delta;
        }),
        child: AnimatedOpacity(
          opacity: isHighlighted ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E2430),
              border: Border.all(
                color: isSelected ? Colors.white : ringColor,
                width: isSelected ? 3.5 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: ringColor.withValues(alpha: isSelected ? 0.7 : 0.3),
                  blurRadius: isSelected ? 20 : 8,
                  spreadRadius: isSelected ? 4 : 1,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  node.name.substring(0, min(node.name.length, 3)).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.formatCompact(node.netBalance.abs()),
                  style: TextStyle(
                    color: ringColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(TextTheme tt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(Colors.white, false, 'Direct debt'),
          const SizedBox(height: 4),
          _legendRow(Colors.white30, true, 'Transitive (A→B→C)'),
          const SizedBox(height: 6),
          _legendDot(const Color(0xFF22C55E), 'Net creditor (owed)'),
          const SizedBox(height: 4),
          _legendDot(const Color(0xFFEF4444), 'Net debtor (owes)'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, bool dashed, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(32, 2),
          painter: _LegendLinePainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildDetailCard(ColorScheme cs, TextTheme tt) {
    final node = _nodes[_selectedNodeId];
    if (node == null) return const SizedBox();

    final owes = _directEdges
        .where((e) => e.fromId == _selectedNodeId)
        .toList();
    final isOwed = _directEdges
        .where((e) => e.toId == _selectedNodeId)
        .toList();

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(node.name, style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: node.netBalance > 0.01
                        ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                        : node.netBalance < -0.01
                            ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                            : Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    node.netBalance > 0.01
                        ? 'Net +${CurrencyFormatter.format(node.netBalance)}'
                        : node.netBalance < -0.01
                            ? 'Net ${CurrencyFormatter.format(node.netBalance)}'
                            : 'Settled',
                    style: TextStyle(
                      color: node.netBalance > 0.01
                          ? const Color(0xFF22C55E)
                          : node.netBalance < -0.01
                              ? const Color(0xFFEF4444)
                              : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (owes.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Owes →', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ...owes.map((e) {
                final target = _nodes[e.toId];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward, size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Text(target?.name ?? '?', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      const Spacer(),
                      Text(CurrencyFormatter.format(e.amount),
                          style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              }),
            ],
            if (isOwed.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Is owed ←', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ...isOwed.map((e) {
                final source = _nodes[e.fromId];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back, size: 14, color: Color(0xFF22C55E)),
                      const SizedBox(width: 6),
                      Text(source?.name ?? '?', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      const Spacer(),
                      Text(CurrencyFormatter.format(e.amount),
                          style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- ER-Style Painter ----------

class _ERGraphPainter extends CustomPainter {
  final Map<int, _Node> nodes;
  final List<_Edge> directEdges;
  final List<_Edge> transitiveEdges;
  final int? selectedNodeId;

  const _ERGraphPainter({
    required this.nodes,
    required this.directEdges,
    required this.transitiveEdges,
    required this.selectedNodeId,
  });

  bool _isEdgeHighlighted(_Edge edge) {
    if (selectedNodeId == null) return true;
    return edge.fromId == selectedNodeId || edge.toId == selectedNodeId;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw transitive curved arcs first (underneath direct edges)
    for (final edge in transitiveEdges) {
      final a = nodes[edge.fromId];
      final b = nodes[edge.toId];
      if (a == null || b == null) continue;

      final highlighted = _isEdgeHighlighted(edge);
      final alpha = highlighted ? 0.45 : 0.12;

      _drawCurvedArrow(canvas, a.position, b.position, alpha, edge.amount, isDirect: false);
    }

    // Draw direct bright white edges on top
    for (final edge in directEdges) {
      final a = nodes[edge.fromId];
      final b = nodes[edge.toId];
      if (a == null || b == null) continue;

      final highlighted = _isEdgeHighlighted(edge);
      final alpha = highlighted ? 1.0 : 0.2;

      _drawStraightArrow(canvas, a.position, b.position, alpha, edge.amount, isDirect: true);
    }
  }

  void _drawStraightArrow(Canvas canvas, Offset start, Offset end, double alpha, double amount, {required bool isDirect}) {
    final delta = end - start;
    final dist = delta.distance;
    if (dist < 5) return;

    final nodeR = 36.0;
    final dir = delta / dist;

    final p1 = start + dir * nodeR;
    final p2 = end - dir * (nodeR + 14); // leave room for arrowhead

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = isDirect ? 1.8 : 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(p1, p2, linePaint);

    // Arrowhead
    _drawArrowhead(canvas, p2, dir, alpha, isDirect);

    // Amount label
    final midpoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    _drawLabel(canvas, midpoint, CurrencyFormatter.formatCompact(amount), alpha);
  }

  void _drawCurvedArrow(Canvas canvas, Offset start, Offset end, double alpha, double amount, {required bool isDirect}) {
    final delta = end - start;
    final dist = delta.distance;
    if (dist < 5) return;

    final nodeR = 36.0;
    final dir = delta / dist;
    final perp = Offset(-dir.dy, dir.dx); // perpendicular

    final p1 = start + dir * nodeR;
    final p2 = end - dir * (nodeR + 14);

    // Control point offset — bow outward by a fraction of distance
    final curvature = dist * 0.35;
    final controlPt = Offset(
      (p1.dx + p2.dx) / 2 + perp.dx * curvature,
      (p1.dy + p2.dy) / 2 + perp.dy * curvature,
    );

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..quadraticBezierTo(controlPt.dx, controlPt.dy, p2.dx, p2.dy);

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Dashed effect for transitive
    _drawDashedPath(canvas, path, paint);

    // Arrow at end of curve — tangent at p2 from control point
    final tangentDir = (p2 - controlPt);
    final tangentNorm = tangentDir / tangentDir.distance;
    _drawArrowhead(canvas, p2, tangentNorm, alpha, false);

    // Label at midpoint of curve
    final labelPt = Offset(
      0.25 * p1.dx + 0.5 * controlPt.dx + 0.25 * p2.dx,
      0.25 * p1.dy + 0.5 * controlPt.dy + 0.25 * p2.dy,
    );
    _drawLabel(canvas, labelPt, CurrencyFormatter.formatCompact(amount), alpha * 0.8);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      bool drawing = true;
      while (dist < metric.length) {
        final step = drawing ? dashLen : gapLen;
        final end = min(dist + step, metric.length);
        if (drawing) {
          canvas.drawPath(metric.extractPath(dist, end), paint);
        }
        dist = end;
        drawing = !drawing;
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset tip, Offset dir, double alpha, bool isDirect) {
    final angle = atan2(dir.dy, dir.dx);
    const spread = pi / 6;
    const len = 10.0;

    final p1 = Offset(
      tip.dx - len * cos(angle - spread),
      tip.dy - len * sin(angle - spread),
    );
    final p2 = Offset(
      tip.dx - len * cos(angle + spread),
      tip.dy - len * sin(angle + spread),
    );

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = isDirect ? 1.6 : 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(tip, p1, paint);
    canvas.drawLine(tip, p2, paint);
  }

  void _drawLabel(Canvas canvas, Offset pos, String text, double alpha) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha * 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = Rect.fromCenter(center: pos, width: tp.width + 10, height: tp.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF0D1117).withValues(alpha: 0.75),
    );
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ERGraphPainter old) =>
      old.nodes != nodes ||
      old.directEdges != directEdges ||
      old.transitiveEdges != transitiveEdges ||
      old.selectedNodeId != selectedNodeId;
}

// ---------- Legend Line Painter ----------

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _LegendLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (!dashed) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    } else {
      double x = 0;
      bool draw = true;
      while (x < size.width) {
        final end = min(x + (draw ? 5.0 : 3.0), size.width);
        if (draw) canvas.drawLine(Offset(x, size.height / 2), Offset(end, size.height / 2), paint);
        x = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
