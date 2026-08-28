import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/core/utils/date_formatter.dart';
import 'package:campus_quicksplit/core/theme/app_spacing.dart';
import 'package:campus_quicksplit/presentation/widgets/staggered_list_item.dart';
import 'package:campus_quicksplit/presentation/widgets/widgets.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<AuditLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final auditRepo = context.read<AuditRepository>();
    final logs = await auditRepo.getAllAuditLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Color _getActionColor(BuildContext context, String actionType) {
    final cs = Theme.of(context).colorScheme;
    switch (actionType) {
      case 'CREATED':
        return const Color(0xFF16A34A);
      case 'UPDATED':
        return cs.tertiary;
      case 'MOVED_TO_BIN':
        return cs.error;
      case 'RESTORED':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType) {
      case 'CREATED':
        return Icons.add_circle;
      case 'UPDATED':
        return Icons.edit;
      case 'MOVED_TO_BIN':
        return Icons.delete;
      case 'RESTORED':
        return Icons.restore;
      default:
        return Icons.history;
    }
  }

  Future<void> _verifyChain() async {
    final auditRepo = context.read<AuditRepository>();
    final auditService = context.read<AuditService>();
    final isValid = await auditService.verifyChainIntegrity(auditRepo);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isValid ? Icons.verified : Icons.warning,
          color: isValid ? const Color(0xFF16A34A) : Theme.of(context).colorScheme.error,
          size: 48,
        ),
        title: Text(isValid ? 'Chain Verified ✓' : 'Chain Broken ✗'),
        content: Text(isValid
            ? 'All audit records are intact. No tampering detected.'
            : 'WARNING: Hash mismatch detected! Local data may have been tampered with outside the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Trail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_user),
            tooltip: 'Verify Blockchain Integrity',
            onPressed: _verifyChain,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: _logs.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        alignment: Alignment.center,
                        child: const EmptyState(
                          icon: Icons.history,
                          message: 'No audit records yet',
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final color = _getActionColor(context, log.actionType);
                        return StaggeredListItem(
                          index: index,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(_getActionIcon(log.actionType),
                                  color: color, size: 20),
                            ),
                            title: Text(
                              '${log.actionType} · Expense #${log.expenseId}',
                              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              DateFormatter.formatRelative(log.timestamp),
                            ),
                            trailing: Text(
                              log.currentHash.substring(0, 8),
                              style: tt.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
