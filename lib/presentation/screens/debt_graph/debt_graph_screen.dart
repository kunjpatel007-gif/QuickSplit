import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class Node {
  final int userId;
  final String name;
  final double netBalance;
  Offset position;
  Offset velocity = Offset.zero;

  Node(this.userId, this.name, this.netBalance, this.position);
}

class Edge {
  final int fromId;
  final int toId;
  final double amount;

  Edge(this.fromId, this.toId, this.amount);
}

class DebtGraphScreen extends StatefulWidget {
  const DebtGraphScreen({super.key});

  @override
  State<DebtGraphScreen> createState() => _DebtGraphScreenState();
}

class _DebtGraphScreenState extends State<DebtGraphScreen> with TickerProviderStateMixin {
  bool _isSimplified = true;
  int? _selectedNodeId;
  late AnimationController _controller;
  late AnimationController _transitionController;
  
  final Map<int, Node> _nodes = {};
  List<Edge> _edges = [];

  bool _isDragging = false;
  int? _draggedNodeId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeGraph();
  }

  @override
  void dispose() {
    _controller.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _initializeGraph() {
    final balanceProvider = context.read<BalanceProvider>();
    final userProvider = context.read<UserProvider>();
    final netBalances = balanceProvider.balances;
    
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    final random = Random();

    _nodes.clear();
    netBalances.forEach((userId, balance) {
      final user = userProvider.getUserById(userId);
      if (user != null) {
        _nodes[userId] = Node(
          userId,
          user.name,
          balance,
          center + Offset(random.nextDouble() * 100 - 50, random.nextDouble() * 100 - 50),
        );
      }
    });

    _updateEdges(netBalances);
    _controller.repeat();
  }

  void _updateEdges(Map<int, double> balances) {
    if (balances.isEmpty) {
      _edges = [];
      return;
    }
    
    List<DebtTransaction> transactions;
    if (_isSimplified) {
      transactions = DebtSimplifier().simplifyDebts(balances);
    } else {
      transactions = _getNaiveDebts(balances);
    }
    
    _edges = transactions.map((tx) => Edge(tx.fromUserId, tx.toUserId, tx.amount)).toList();
  }

  List<DebtTransaction> _getNaiveDebts(Map<int, double> balances) {
    final debtors = balances.entries.where((e) => e.value < -0.01).toList();
    final creditors = balances.entries.where((e) => e.value > 0.01).toList();
    
    debtors.sort((a, b) => a.value.compareTo(b.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    List<DebtTransaction> transactions = [];
    int i = 0, j = 0;
    
    List<MapEntry<int, double>> mDebtors = List.from(debtors);
    List<MapEntry<int, double>> mCreditors = List.from(creditors);

    while (i < mDebtors.length && j < mCreditors.length) {
      double debt = -mDebtors[i].value;
      double credit = mCreditors[j].value;
      
      double amount = debt < credit ? debt : credit;
      
      if (amount > 0.01) {
        transactions.add(DebtTransaction(
          fromUserId: mDebtors[i].key,
          toUserId: mCreditors[j].key,
          amount: amount,
        ));
      }
      
      mDebtors[i] = MapEntry(mDebtors[i].key, mDebtors[i].value + amount);
      mCreditors[j] = MapEntry(mCreditors[j].key, mCreditors[j].value - amount);
      
      if (-mDebtors[i].value < 0.01) i++;
      if (mCreditors[j].value < 0.01) j++;
    }
    return transactions;
  }

  void _tick() {
    if (_nodes.isEmpty) return;
    
    const double repulsionForce = 5000.0;
    const double springForce = 0.01;
    const double damping = 0.85;

    final List<Node> nodeList = _nodes.values.toList();
    
    for (int i = 0; i < nodeList.length; i++) {
      for (int j = i + 1; j < nodeList.length; j++) {
        final nodeA = nodeList[i];
        final nodeB = nodeList[j];
        
        final delta = nodeB.position - nodeA.position;
        final distance = delta.distance;
        
        if (distance > 0) {
          final repulse = (repulsionForce / (distance * distance));
          final force = (delta / distance) * repulse;
          
          if (nodeA.userId != _draggedNodeId) nodeA.velocity -= force;
          if (nodeB.userId != _draggedNodeId) nodeB.velocity += force;
        }
      }
    }

    for (final edge in _edges) {
      final nodeA = _nodes[edge.fromId];
      final nodeB = _nodes[edge.toId];
      if (nodeA != null && nodeB != null) {
        final delta = nodeB.position - nodeA.position;
        final distance = delta.distance;
        
        final force = delta * springForce;
        
        if (nodeA.userId != _draggedNodeId) nodeA.velocity += force;
        if (nodeB.userId != _draggedNodeId) nodeB.velocity -= force;
      }
    }

    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    for (final node in nodeList) {
      if (node.userId == _draggedNodeId) continue;

      final deltaCenter = center - node.position;
      node.velocity += deltaCenter * 0.005;
      
      node.position += node.velocity;
      node.velocity *= damping;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Debt Graph'),
        actions: [
          Row(
            children: [
              const Text('Simplified'),
              Switch(
                value: _isSimplified,
                onChanged: (val) async {
                  if (_isSimplified == val) return;
                  await _transitionController.reverse();
                  setState(() {
                    _isSimplified = val;
                    final balances = context.read<BalanceProvider>().balances;
                    _updateEdges(balances);
                  });
                  _transitionController.forward();
                },
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: _nodes.isEmpty
          ? const Center(child: Text('No debt data available'))
          : GestureDetector(
              onPanUpdate: (details) {
                if (_isDragging && _draggedNodeId != null) {
                  setState(() {
                    _nodes[_draggedNodeId!]!.position += details.delta;
                  });
                }
              },
              onPanEnd: (_) {
                _isDragging = false;
                _draggedNodeId = null;
              },
              child: CustomPaint(
                painter: GraphPainter(
                  nodes: _nodes,
                  edges: _edges,
                  selectedNodeId: _selectedNodeId,
                  edgeOpacity: _transitionController.value,
                  colorScheme: cs,
                ),
                child: Stack(
                  children: _nodes.values.map((node) {
                    final isSelected = _selectedNodeId == node.userId;
                    
                    Color nodeColor = cs.outlineVariant;
                    if (node.netBalance > 0.01) nodeColor = const Color(0xFF16A34A);
                    else if (node.netBalance < -0.01) nodeColor = cs.error;
                    
                    return Positioned(
                      left: node.position.dx - 30,
                      top: node.position.dy - 30,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedNodeId == node.userId) {
                              _selectedNodeId = null;
                            } else {
                              _selectedNodeId = node.userId;
                            }
                          });
                        },
                        onPanStart: (details) {
                          _isDragging = true;
                          _draggedNodeId = node.userId;
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: nodeColor,
                            border: Border.all(
                              color: isSelected ? cs.primary : cs.onPrimary,
                              width: isSelected ? 4 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  node.name.substring(0, min(node.name.length, 3)).toUpperCase(),
                                  style: TextStyle(
                                    color: cs.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isSelected)
                                  Text(
                                    CurrencyFormatter.formatCompact(node.netBalance.abs()),
                                    style: TextStyle(
                                      color: cs.onPrimary,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final Map<int, Node> nodes;
  final List<Edge> edges;
  final int? selectedNodeId;
  final double edgeOpacity;
  final ColorScheme colorScheme;

  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.selectedNodeId,
    this.edgeOpacity = 1.0,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final nodeA = nodes[edge.fromId];
      final nodeB = nodes[edge.toId];
      if (nodeA == null || nodeB == null) continue;

      final isHighlighted = selectedNodeId == null || 
                            selectedNodeId == edge.fromId || 
                            selectedNodeId == edge.toId;
      
      Color colorToUse = isHighlighted ? colorScheme.outlineVariant : colorScheme.outlineVariant; // Keeping both similar to blueGrey and grey logic but with theme aware outlineVariant
      double targetAlpha = isHighlighted ? 1.0 : 0.2;
      
      final paint = Paint()
        ..color = colorToUse.withValues(alpha: targetAlpha * edgeOpacity)
        ..strokeWidth = isHighlighted ? 2.0 : 1.0
        ..style = PaintingStyle.stroke;

      final start = nodeA.position;
      final end = nodeB.position;
      canvas.drawLine(start, end, paint);

      if (isHighlighted) {
        _drawArrow(canvas, start, end, paint);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    if (delta.distance < 60) return;
    
    final direction = delta / delta.distance;
    final arrowPoint = end - (direction * 40);
    
    final angle = atan2(direction.dy, direction.dx);
    final arrowAngle = pi / 6;
    final length = 15.0;

    final path = Path();
    path.moveTo(arrowPoint.dx, arrowPoint.dy);
    path.lineTo(
      arrowPoint.dx - length * cos(angle - arrowAngle),
      arrowPoint.dy - length * sin(angle - arrowAngle),
    );
    path.moveTo(arrowPoint.dx, arrowPoint.dy);
    path.lineTo(
      arrowPoint.dx - length * cos(angle + arrowAngle),
      arrowPoint.dy - length * sin(angle + arrowAngle),
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
