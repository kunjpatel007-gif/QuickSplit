import 'package:flutter/material.dart';

/// Wraps a child widget with a staggered slide-up + fade-in entrance animation.
///
/// Only animates on the first build. Respects reduced-motion accessibility settings.
///
/// Usage:
/// ```dart
/// StaggeredListItem(
///   index: index,
///   child: MyTile(...),
/// )
/// ```
class StaggeredListItem extends StatefulWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
  });

  final int index;
  final Widget child;
  final Duration staggerDelay;
  final Duration duration;
  final Curve curve;

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Respect accessibility: skip animation if reduced motion is preferred
    final reduceMotion = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first,
    ).disableAnimations;

    if (reduceMotion) {
      _controller.value = 1.0;
      _hasAnimated = true;
      return;
    }

    // Calculate stagger delay based on index
    final delay = widget.staggerDelay * widget.index;
    await Future.delayed(delay);

    if (mounted && !_hasAnimated) {
      _hasAnimated = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
