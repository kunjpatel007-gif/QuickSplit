import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';

class AuditService {
  String generateHash({
    required int expenseId,
    required String actionType,
    double? previousAmount,
    double? newAmount,
    required String timestamp,
    required String previousHash,
  }) {
    final String data =
        '$expenseId|$actionType|$previousAmount|$newAmount|$timestamp|$previousHash';
    final List<int> bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<AuditLog> createAuditEntry({
    required int expenseId,
    required String actionType,
    double? previousAmount,
    double? newAmount,
    required AuditRepository auditRepo,
  }) async {
    final String latestHash = await auditRepo.getLatestHash() ?? 'GENESIS';
    final DateTime now = DateTime.now().toUtc();
    final String timestampStr = now.toIso8601String();

    final String newHash = generateHash(
      expenseId: expenseId,
      actionType: actionType,
      previousAmount: previousAmount,
      newAmount: newAmount,
      timestamp: timestampStr,
      previousHash: latestHash,
    );

    return AuditLog(
      expenseId: expenseId,
      actionType: actionType,
      previousAmount: previousAmount,
      newAmount: newAmount,
      timestamp: now,
      previousHash: latestHash,
      currentHash: newHash,
    );
  }

  Future<bool> verifyChainIntegrity(AuditRepository auditRepo) async {
    final List<AuditLog> logs = await auditRepo.getAllAuditLogs();

    for (int i = 0; i < logs.length; i++) {
      final AuditLog currentLog = logs[i];

      final String expectedHash = generateHash(
        expenseId: currentLog.expenseId,
        actionType: currentLog.actionType,
        previousAmount: currentLog.previousAmount,
        newAmount: currentLog.newAmount,
        timestamp: currentLog.timestamp.toIso8601String(),
        previousHash: currentLog.previousHash,
      );

      if (expectedHash != currentLog.currentHash) {
        return false;
      }
    }
    return true;
  }
}
