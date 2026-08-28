import 'package:flutter/material.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // Trigger fade-in after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 56,
                color: cs.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton.tonal(
                  onPressed: widget.onAction,
                  child: Text(widget.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
