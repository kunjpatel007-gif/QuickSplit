import 'package:flutter/material.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.user,
    required this.balance,
  });

  final User user;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Semantic balance color
    final Color accent;
    if (balance > 0) {
      accent = const Color(0xFF16A34A); // Green 600
    } else if (balance < 0) {
      accent = cs.error;
    } else {
      accent = cs.onSurfaceVariant;
    }

    return SizedBox(
      width: 130,
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + 2,
          vertical: AppSpacing.xs,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: tt.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.name,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                child: Text(
                  CurrencyFormatter.formatCompact(balance),
                  key: ValueKey(balance),
                  style: tt.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
