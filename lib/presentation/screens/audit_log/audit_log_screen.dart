import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/core/utils/date_formatter.dart';

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

  Color _getActionColor(String actionType) {
    switch (actionType) {
      case 'CREATED':
        return const Color(0xFF16A34A);
      case 'UPDATED':
        return const Color(0xFFb8c3ff);
      case 'MOVED_TO_BIN':
        return const Color(0xFFffb4ab);
      case 'RESTORED':
        return const Color(0xFFffb800);
      default:
        return const Color(0xFFe5e2e3);
    }
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType) {
      case 'CREATED': return Icons.add;
      case 'UPDATED': return Icons.edit;
      case 'MOVED_TO_BIN': return Icons.delete;
      case 'RESTORED': return Icons.restore;
      default: return Icons.history;
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
        backgroundColor: const Color(0xFF201f20),
        shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF514532), width: 2)),
        title: Row(
          children: [
            Icon(isValid ? Icons.verified : Icons.warning, color: isValid ? const Color(0xFF16A34A) : const Color(0xFFffb4ab), size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(isValid ? 'CHAIN VERIFIED' : 'CHAIN BROKEN', style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          isValid
              ? 'ALL AUDIT RECORDS ARE INTACT. NO TAMPERING DETECTED.'
              : 'WARNING: HASH MISMATCH DETECTED! LOCAL DATA MAY HAVE BEEN TAMPERED WITH OUTSIDE THE APP.',
          style: GoogleFonts.jetBrainsMono(color: const Color(0xFF9e8f78)),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFffb800),
              foregroundColor: const Color(0xFF131314),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('ACKNOWLEDGE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131314),
        title: Text('AUDIT_TRAIL', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: const Color(0xFFe5e2e3))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFF514532), height: 2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_user, color: Color(0xFFffb800)),
            tooltip: 'VERIFY LEDGER INTEGRITY',
            onPressed: _verifyChain,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFffb800)))
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: _logs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(child: Text('NO AUDIT RECORDS FOUND', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF514532))))
                        )
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final color = _getActionColor(log.actionType);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF201f20),
                            border: Border.all(color: const Color(0xFF514532)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131314),
                                  border: Border.all(color: color),
                                ),
                                child: Icon(_getActionIcon(log.actionType), color: color, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${log.actionType} · TXN #${log.expenseId}', style: GoogleFonts.jetBrainsMono(color: const Color(0xFFe5e2e3), fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(DateFormatter.formatRelative(log.timestamp).toUpperCase(), style: GoogleFonts.jetBrainsMono(color: const Color(0xFF9e8f78), fontSize: 10)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('HASH', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF514532), fontSize: 10)),
                                  Text(log.currentHash.substring(0, 8), style: GoogleFonts.jetBrainsMono(color: const Color(0xFFb8c3ff), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
