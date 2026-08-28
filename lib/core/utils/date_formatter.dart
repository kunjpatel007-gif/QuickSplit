import 'package:intl/intl.dart';

class DateFormatter {
  static String format(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  static String formatShort(DateTime dt) {
    return DateFormat('dd MMM').format(dt);
  }

  static String formatRelative(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return formatShort(dt);
    }
  }
}
