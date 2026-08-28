import 'package:flutter/material.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/core/constants/category_icons.dart';
import 'package:campus_quicksplit/core/utils/currency_formatter.dart';
import 'package:campus_quicksplit/core/utils/date_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    this.onTap,
    this.onDismissed,
  });

  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final catColor = CategoryIcons.getColor(expense.category);

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(Icons.delete_rounded, color: cs.onError),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        leading: CircleAvatar(
          backgroundColor: catColor.withValues(alpha: 0.12),
          child: Icon(
            CategoryIcons.getIcon(expense.category),
            color: catColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                expense.title,
                style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (expense.isRecurring)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  Icons.repeat_rounded,
                  size: 16,
                  color: cs.primary,
                ),
              ),
          ],
        ),
        subtitle: Text(
          DateFormatter.formatRelative(expense.timestamp),
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: Text(
          CurrencyFormatter.format(expense.totalAmount),
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
