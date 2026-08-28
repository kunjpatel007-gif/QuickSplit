class ParsedExpense {
  final double? amount;
  final String? title;
  final String? category;
  final String? payerName;
  final List<String> participants;

  const ParsedExpense({
    this.amount,
    this.title,
    this.category,
    this.payerName,
    this.participants = const [],
  });
}

class NlpParser {
  static const Map<String, List<String>> _categoryKeywords = {
    'Food': ['pizza', 'burger', 'biryani', 'chai', 'coffee', 'maggi', 'food', 'lunch', 'dinner', 'breakfast', 'snack', 'nescafe', 'restaurant'],
    'Transport': ['auto', 'uber', 'ola', 'cab', 'metro', 'bus', 'train', 'ride', 'fuel', 'petrol'],
    'Entertainment': ['movie', 'netflix', 'spotify', 'hotstar', 'prime', 'subscription', 'game'],
    'Shopping': ['amazon', 'flipkart', 'clothes', 'shoes', 'shopping'],
    'Education': ['printout', 'xerox', 'book', 'notes', 'stationery', 'copy'],
    'Utilities': ['recharge', 'electricity', 'wifi', 'water', 'bill'],
  };

  ParsedExpense parse(String input) {
    final String lowerInput = input.toLowerCase();
    
    // Extract amount
    double? amount;
    final RegExp amountRegExp = RegExp(r'(?:rs\.?|₹)?\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false);
    final Match? amountMatch = amountRegExp.firstMatch(input);
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!);
    }

    // Extract category
    String category = 'Other';
    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerInput.contains(keyword)) {
          category = entry.key;
          break;
        }
      }
      if (category != 'Other') break;
    }

    // Extract title (words after 'for')
    String? title;
    final RegExp forRegExp = RegExp(r'\bfor\b\s+(.+?)(?=\bwith\b|$)', caseSensitive: false);
    final Match? forMatch = forRegExp.firstMatch(input);
    if (forMatch != null) {
      title = forMatch.group(1)?.trim();
    }

    // Extract participants (names starting with Uppercase after 'with')
    List<String> participants = [];
    final RegExp withRegExp = RegExp(r'\bwith\b\s+(.+)$', caseSensitive: false);
    final Match? withMatch = withRegExp.firstMatch(input);
    if (withMatch != null) {
      final String afterWith = withMatch.group(1) ?? '';
      final RegExp nameRegExp = RegExp(r'\b[A-Z][a-z]*\b');
      final Iterable<Match> nameMatches = nameRegExp.allMatches(afterWith);
      for (final match in nameMatches) {
        participants.add(match.group(0)!);
      }
    }

    // Extract payer (word before 'paid')
    String? payerName;
    final RegExp payerRegExp = RegExp(r'^([a-zA-Z]+)\s+paid\b', caseSensitive: false);
    final Match? payerMatch = payerRegExp.firstMatch(input.trim());
    if (payerMatch != null) {
      payerName = payerMatch.group(1);
    }

    return ParsedExpense(
      amount: amount,
      title: title,
      category: category,
      payerName: payerName,
      participants: participants,
    );
  }
}
