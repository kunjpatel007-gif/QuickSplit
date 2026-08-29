class ParsedExpense {
  final double? amount;
  final String? title;
  final String? category;
  final String? payerName;
  final List<String> participants;
  
  // Pro-rata fields
  final bool isProRata;
  final double taxAmount;
  final List<NlpItem> items;

  const ParsedExpense({
    this.amount,
    this.title,
    this.category,
    this.payerName,
    this.participants = const [],
    this.isProRata = false,
    this.taxAmount = 0.0,
    this.items = const [],
  });
}

class NlpItem {
  final String person;
  final String item;
  final double amount;
  
  const NlpItem(this.person, this.item, this.amount);
}

class NlpParser {
  static const Map<String, List<String>> _categoryKeywords = {
    'Food': ['pizza', 'burger', 'biryani', 'chai', 'coffee', 'maggi', 'food', 'lunch', 'dinner', 'breakfast', 'snack', 'nescafe', 'restaurant', 'pasta'],
    'Transport': ['auto', 'uber', 'ola', 'cab', 'metro', 'bus', 'train', 'ride', 'fuel', 'petrol'],
    'Entertainment': ['movie', 'netflix', 'spotify', 'hotstar', 'prime', 'subscription', 'game'],
    'Shopping': ['amazon', 'flipkart', 'clothes', 'shoes', 'shopping'],
    'Education': ['printout', 'xerox', 'book', 'notes', 'stationery', 'copy'],
    'Utilities': ['recharge', 'electricity', 'wifi', 'water', 'bill'],
  };

  ParsedExpense parse(String input) {
    final String lowerInput = input.toLowerCase();
    
    // 1. Pro-Rata Parsing Check
    if (lowerInput.contains('ordered') || lowerInput.contains('got') || lowerInput.contains('had')) {
      final items = <NlpItem>[];
      double taxAmount = 0.0;
      
      // Parse taxes: "taxes were 120" or "gst 120"
      final taxRegExp = RegExp(r'(?:tax(?:es)?|gst|tip|service charge|fee)[^\d]*(\d+(?:\.\d{1,2})?)', caseSensitive: false);
      final taxMatch = taxRegExp.firstMatch(input);
      if (taxMatch != null) {
        taxAmount = double.tryParse(taxMatch.group(1)!) ?? 0.0;
      }
      
      // Parse items: "I ordered pizza for 500" or "kunj ordered pasta for 600"
      // Match: (Person) (ordered/got/had) (Item) for (Amount)
      final itemRegExp = RegExp(r'\b([a-zA-Z]+)\s+(?:ordered|got|had)\s+(.+?)\s+for\s+(\d+(?:\.\d{1,2})?)', caseSensitive: false);
      final matches = itemRegExp.allMatches(input);
      
      for (final m in matches) {
        final person = m.group(1)!.trim();
        final item = m.group(2)!.trim();
        final amt = double.tryParse(m.group(3)!) ?? 0.0;
        items.add(NlpItem(person, item, amt));
      }
      
      if (items.isNotEmpty) {
        double subtotal = items.fold(0, (sum, i) => sum + i.amount);
        double totalAmount = subtotal + taxAmount;
        
        // Infer category based on the first item
        String category = 'Other';
        for (final entry in _categoryKeywords.entries) {
          for (final keyword in entry.value) {
            if (items.first.item.toLowerCase().contains(keyword)) {
              category = entry.key;
              break;
            }
          }
          if (category != 'Other') break;
        }
        
        // Infer title
        String title = items.map((i) => i.item).join(' & ');
        
        return ParsedExpense(
          amount: totalAmount,
          title: title,
          category: category,
          isProRata: true,
          taxAmount: taxAmount,
          items: items,
        );
      }
    }
    
    // 2. Standard Parsing Fallback
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
