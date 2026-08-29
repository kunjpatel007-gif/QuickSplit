import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/user_repository.dart';
import 'package:campus_quicksplit/domain/providers/user_provider.dart';

class SyncUtils {
  /// Deduplication logic checking title, amount, and day.
  static bool isDuplicateExpense(Expense ex, String title, double amount, DateTime ts) {
    return ex.title == title &&
        ex.totalAmount == amount &&
        ex.timestamp.year == ts.year &&
        ex.timestamp.month == ts.month &&
        ex.timestamp.day == ts.day;
  }

  /// Creates a User Payload map for JSON encoding.
  static Map<String, dynamic> buildUserPayload(User user, double amount, String amountKey) {
    return {
      'syncId': user.syncId,
      'userName': user.name,
      amountKey: amount,
    };
  }

  /// Resolves a user by syncId, then name, or creates them.
  static Future<User?> resolveUser(
    Map<String, dynamic> entry,
    UserRepository userRepo,
    UserProvider userProvider,
  ) async {
    final syncId = entry['syncId'] as String?;
    final name = entry['userName'] as String;
    User? user;
    if (syncId != null && syncId.isNotEmpty) {
      user = await userRepo.getUserBySyncId(syncId);
    }
    user ??= await userRepo.getUserByName(name);
    
    if (user == null) {
      await userRepo.insertUser(User(syncId: syncId ?? '', name: name, createdAt: DateTime.now()));
      await userProvider.loadUsers();
      user = syncId != null && syncId.isNotEmpty
          ? await userRepo.getUserBySyncId(syncId)
          : await userRepo.getUserByName(name);
    }
    return user;
  }
}
