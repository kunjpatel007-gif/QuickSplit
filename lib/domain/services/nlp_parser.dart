import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

/// Parses free-form "Magic Typer" text into a [ParsedExpense].
///
/// Handles two flows:
///  1. Pro-rata / itemized sentences ("I ordered pizza for 500 and Kunj
///     ordered pasta for 600, taxes were 120") -> [ParsedExpense.isProRata].
///  2. Standard sentences ("Lunch 500 with Kunj and Mitul", "Mitul paid 300
///     for Uber with Kunj") -> plain amount/title/category/payer/participants.
///
/// Notes / known limitations:
///  - Numbers may use Indian-style comma grouping ("1,200" or "1,00,000").
///  - Multiple tax-like mentions ("tax 100 and tip 50") are summed together.
///  - Category matching is whole-word, so "cab" won't match inside "cabbage".
///  - `parse()` never throws — it's called on every keystroke against
///    partial, incomplete input, so any failure just yields a blank
///    [ParsedExpense] instead of crashing the form.
class ParsedExpense {
  final double? amount;
  final String? title;
  final String? category;
  final String? payerName;
  final List<String> participants;
  final DateTime? date;
  final Map<String, double> multiPayers;

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
    this.date,
    this.multiPayers = const {},
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
    'Food': [
      'pizza', 'burger', 'biryani', 'chai', 'coffee', 'maggi', 'food',
      'lunch', 'dinner', 'breakfast', 'snack', 'nescafe', 'restaurant',
      'pasta',
    ],
    'Transport': [
      'auto', 'uber', 'ola', 'cab', 'metro', 'bus', 'train', 'ride',
      'fuel', 'petrol',
    ],
    'Entertainment': [
      'movie', 'netflix', 'spotify', 'hotstar', 'prime', 'subscription',
      'game',
    ],
    'Shopping': ['amazon', 'flipkart', 'clothes', 'shoes', 'shopping'],
    'Education': [
      'printout', 'xerox', 'book', 'notes', 'stationery', 'copy',
    ],
    'Utilities': ['recharge', 'electricity', 'wifi', 'water', 'bill'],
  };

  // Precompiled, word-boundary-safe keyword matchers, built once instead of
  // per keystroke. Word boundaries stop e.g. "cab" from matching "cabbage".
  static final Map<String, List<RegExp>> _categoryKeywordRegexes =
      _buildCategoryRegexes();

  static Map<String, List<RegExp>> _buildCategoryRegexes() {
    final map = <String, List<RegExp>>{};
    for (final entry in _categoryKeywords.entries) {
      map[entry.key] = entry.value
          .map((k) => RegExp('\\b${RegExp.escape(k)}\\b', caseSensitive: false))
          .toList();
    }
    return map;
  }

  // Words that should never be treated as a participant/payer name even
  // though they get capitalized at the start of a sentence or clause.
  static const Set<String> _nameStopWords = {
    'and', 'the', 'for', 'with', 'was', 'were', 'are', 'is', 'to', 'of',
    'a', 'an', 'in', 'on', 'at', 'today', 'yesterday', 'tomorrow', 'i',
    'me', 'my', 'we', 'us', 'paid', 'tax', 'taxes', 'gst', 'tip', 'by',
  };

  // Digits with optional Indian-style comma grouping and an optional
  static const String _numPattern = r'\d+(?:,\d+)*(?:\.\d{1,2})?';

  static final RegExp _itemVerbRegExp =
      RegExp(r'\b(ordered|orderd|got|had|bought|took)\b', caseSensitive: false);

  static final RegExp _itemWithForRegExp = RegExp(
    '(?:\\b([A-Za-z]+)\\s+)?\\b(?:ordered|orderd|got|had|bought|took)\\s+(.+?)\\s+for\\s+(?:rs\\.?|₹|inr)?\\s*($_numPattern)',
    caseSensitive: false,
  );

  // Fallback for sentences that skip the word "for", e.g. "I got coffee 100".
  static final RegExp _itemNoForRegExp = RegExp(
    '(?:\\b([A-Za-z]+)\\s+)?\\b(?:ordered|orderd|got|had|bought|took)\\s+([a-zA-Z][a-zA-Z\\s]*?)\\s+(?:rs\\.?|₹|inr)?\\s*($_numPattern)\\b',
    caseSensitive: false,
  );

  // "X paid Y" or "paid Y" clauses
  static final RegExp _poolPayerRegExp = RegExp(
    '(?:\\b([A-Za-z]+)\\s+)?\\bpaid\\s+(?:rs\\.?|₹|inr)?\\s*($_numPattern)',
    caseSensitive: false,
  );

  // Matches "tax 100", "100 tax", "125 taxes", "tip 50"
  static final RegExp _taxRegExp = RegExp(
    r'(?:\b(?:tax(?:es)?|gst|tip|service\s*charge|fee)s?\b\s*(?:is\s+|are\s+|was\s+|were\s+|for\s+|=)?\s*(' + _numPattern + '))|'
    r'(?:(' + _numPattern + r')\s*(?:tax(?:es)?|gst|tip|service\s*charge|fee)s?\b)',
    caseSensitive: false,
  );

  static final RegExp _currencyAmountRegExp = RegExp(
    '(?:rs\\.?|₹|inr)\\s*($_numPattern)|($_numPattern)\\s*(?:rs\\.?|rupees|inr)\\b',
    caseSensitive: false,
  );

  static final RegExp _bareAmountRegExp = RegExp('\\b($_numPattern)\\b');

  static final RegExp _forClauseRegExp = RegExp(
    r'\bfor\b\s+(.+?)(?=\bwith\b|\bpaid\b|$)',
    caseSensitive: false,
  );

  // "Kunj paid" or "paid by Kunj" — tried in that order of confidence.
  static final RegExp _payerByRegExp =
      RegExp(r'\bpaid\s+by\s+([A-Za-z]+)\b', caseSensitive: false);
  static final RegExp _payerSuffixRegExp =
      RegExp(r'\b([A-Za-z]+)\s+paid\b', caseSensitive: false);

  static final RegExp _withClauseRegExp =
      RegExp(r'\bwith\b\s+(.+)$', caseSensitive: false);

  static final RegExp _capitalizedNameRegExp =
      RegExp(r'\b[A-Z][a-zA-Z]*\b');

  static final RegExp _numberLikeRegExp = RegExp(
    '(?:rs\\.?|₹|inr)?\\s*$_numPattern\\s*(?:rs\\.?|rupees|inr)?',
    caseSensitive: false,
  );

  static final RegExp _trailingWithClauseRegExp =
      RegExp(r'\bwith\b.*$', caseSensitive: false);

  static final RegExp _paidWordRegExp =
      RegExp(r'\bpaid\b', caseSensitive: false);

  static final RegExp _whitespaceRegExp = RegExp(r'\s+');

  static final RegExp _leadingConjunctionRegExp =
      RegExp(r'^(?:and|,)\s+', caseSensitive: false);

  static final RegExp _leadingArticleRegExp =
      RegExp(r'^(?:a|an|the)\s+', caseSensitive: false);

  static final RegExp _trailingPunctuationRegExp = RegExp(r'[.,;:]+$');

  final _entityExtractor = EntityExtractor(language: EntityExtractorLanguage.english);

  /// Parses free-form text typed into the "Magic Typer" field.
  ///
  /// This is called on every keystroke, so it must never throw and should
  /// degrade gracefully on incomplete or malformed input.
  Future<ParsedExpense> parse(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const ParsedExpense();

    try {
      final proRata = _tryParseProRata(trimmed);
      if (proRata != null) return proRata;
      
      final multiPayer = _tryParseMultiPayer(trimmed);
      if (multiPayer != null) return multiPayer;

      return await _parseStandard(trimmed);
    } catch (_) {
      // Never let a partially-typed sentence crash the UI.
      return const ParsedExpense();
    }
  }

  void dispose() {
    _entityExtractor.close();
  }

  double? _parseAmount(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }

  ParsedExpense? _tryParseProRata(String input) {
    if (!_itemVerbRegExp.hasMatch(input)) return null;

    var items = _extractItems(input, _itemWithForRegExp);
    if (items.isEmpty) {
      items = _extractItems(input, _itemNoForRegExp);
    }
    if (items.isEmpty) return null;

    double taxAmount = 0.0;
    for (final m in _taxRegExp.allMatches(input)) {
      taxAmount += _parseAmount(m.group(1) ?? m.group(2)) ?? 0.0;
    }

    final subtotal = items.fold<double>(0, (sum, i) => sum + i.amount);
    final totalAmount = subtotal + taxAmount;

    final category = _inferCategory(items.map((i) => i.item).join(' '));
    final title = items.map((i) => i.item).join(' & ');

    return ParsedExpense(
      amount: totalAmount,
      title: title,
      category: category,
      isProRata: true,
      taxAmount: taxAmount,
      items: items,
    );
  }

  ParsedExpense? _tryParseMultiPayer(String input) {
    final matches = _poolPayerRegExp.allMatches(input);
    if (matches.length < 2) return null; 

    final multiPayers = <String, double>{};
    double totalAmount = 0;

    for (final m in matches) {
      final rawPerson = m.group(1)?.trim();
      final person = (rawPerson == null || rawPerson.isEmpty) ? 'I' : rawPerson;
      final amt = _parseAmount(m.group(2)) ?? 0.0;
      if (amt > 0) {
        multiPayers[person] = (multiPayers[person] ?? 0) + amt;
        totalAmount += amt;
      }
    }

    if (multiPayers.length < 2) return null; 

    double taxAmount = 0.0;
    for (final m in _taxRegExp.allMatches(input)) {
      taxAmount += _parseAmount(m.group(1) ?? m.group(2)) ?? 0.0;
    }

    final items = <NlpItem>[];

    if (taxAmount > 0 && totalAmount > 0) {
      final oldMultiPayers = Map<String, double>.from(multiPayers);
      multiPayers.clear();
      oldMultiPayers.forEach((person, amt) {
        items.add(NlpItem(person, 'Pooled', amt));
        multiPayers[person] = amt + (amt / totalAmount) * taxAmount;
      });
    } else {
      multiPayers.forEach((person, amt) {
        items.add(NlpItem(person, 'Pooled', amt));
      });
    }

    final category = _inferCategory(input);
    
    String? title;
    final forMatch = _forClauseRegExp.firstMatch(input);
    if (forMatch != null) {
      title = _stripTrailingPunctuation(forMatch.group(1)?.trim() ?? '');
    }
    if (title == null || title.isEmpty) {
      var stripped = input;
      for (final m in matches) {
        stripped = stripped.replaceFirst(m.group(0)!, '');
      }
      stripped = stripped.replaceAll(_whitespaceRegExp, ' ').trim();
      stripped = _stripTrailingPunctuation(stripped);
      title = stripped.isNotEmpty ? stripped : null;
    }

    return ParsedExpense(
      amount: totalAmount + taxAmount,
      title: title,
      category: category,
      multiPayers: multiPayers,
      participants: multiPayers.keys.toList(),
      isProRata: true,
      taxAmount: taxAmount,
      items: items,
    );
  }

  List<NlpItem> _extractItems(String input, RegExp pattern) {
    final items = <NlpItem>[];
    for (final m in pattern.allMatches(input)) {
      final rawPerson = m.group(1)?.trim();
      final person =
          (rawPerson == null || rawPerson.isEmpty) ? 'I' : rawPerson;
      final rawItem = m.group(2)?.trim() ?? '';
      final item = _cleanItemName(rawItem);
      final amt = _parseAmount(m.group(3)) ?? 0.0;

      if (amt > 0 && item.isNotEmpty) {
        items.add(NlpItem(person, item, amt));
      }
    }
    return items;
  }

  String _cleanItemName(String raw) {
    // Strip a leading conjunction/article that can leak in from the
    // previous clause, e.g. "... and Kunj ordered pasta" or "ordered a
    // pizza for 500".
    var cleaned = raw.replaceFirst(_leadingConjunctionRegExp, '');
    cleaned = cleaned.replaceFirst(_leadingArticleRegExp, '');
    cleaned = cleaned.replaceAll(_whitespaceRegExp, ' ').trim();
    cleaned = cleaned.replaceFirst(_trailingPunctuationRegExp, '');
    return cleaned;
  }

  Future<ParsedExpense> _parseStandard(String input) async {
    double? amount;
    DateTime? extractedDate;
    List<String> rawPersons = [];

    try {
      final annotations = await _entityExtractor.annotateText(input);
      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          if (entity.type == EntityType.money) {
            final moneyEntity = entity as MoneyEntity;
            amount ??= double.tryParse(moneyEntity.unnormalizedCurrency.replaceAll(',', ''));
          } else if (entity.type == EntityType.dateTime) {
            final dtEntity = entity as DateTimeEntity;
            extractedDate ??= DateTime.fromMillisecondsSinceEpoch(dtEntity.timestamp);
          }
        }
      }
    } catch (_) {
      // Ignore ML Kit errors and fallback
    }

    if (amount == null) {
      final currencyMatch = _currencyAmountRegExp.firstMatch(input);
      if (currencyMatch != null) {
        amount = _parseAmount(currencyMatch.group(1) ?? currencyMatch.group(2));
      } else {
        final bareMatch = _bareAmountRegExp.firstMatch(input);
        if (bareMatch != null) {
          amount = _parseAmount(bareMatch.group(1));
        }
      }
    }

    final category = _inferCategory(input);

    String? title;
    final forMatch = _forClauseRegExp.firstMatch(input);
    if (forMatch != null) {
      final captured = forMatch.group(1)?.trim();
      if (captured != null && captured.isNotEmpty) {
        title = _stripTrailingPunctuation(captured);
      }
    }
    if (title == null) {
      var stripped = input.replaceAll(_numberLikeRegExp, '');
      stripped = stripped.replaceAll(_trailingWithClauseRegExp, '');
      stripped = stripped.replaceAll(_paidWordRegExp, '');
      stripped = stripped.replaceAll(_whitespaceRegExp, ' ').trim();
      stripped = _stripTrailingPunctuation(stripped);
      title = stripped.isNotEmpty ? stripped : null;
    }

    String? payerName;
    final payerByMatch = _payerByRegExp.firstMatch(input);
    if (payerByMatch != null) {
      final candidate = payerByMatch.group(1);
      if (candidate != null &&
          !_nameStopWords.contains(candidate.toLowerCase())) {
        payerName = candidate;
      }
    }
    if (payerName == null) {
      final payerMatch = _payerSuffixRegExp.firstMatch(input);
      if (payerMatch != null) {
        final candidate = payerMatch.group(1);
        if (candidate != null &&
            !_nameStopWords.contains(candidate.toLowerCase())) {
          payerName = candidate;
        }
      }
    }

    final participants = <String>[];
    final withMatch = _withClauseRegExp.firstMatch(input);
    if (withMatch != null) {
      final afterWith = withMatch.group(1) ?? '';
      for (final m in _capitalizedNameRegExp.allMatches(afterWith)) {
        final name = m.group(0)!;
        if (!_nameStopWords.contains(name.toLowerCase()) &&
            !participants.contains(name) && name != payerName) {
          participants.add(name);
        }
      }
    }
    
    for (final person in rawPersons) {
       if (person != payerName && !participants.contains(person)) {
           participants.add(person);
       }
    }

    return ParsedExpense(
      amount: amount,
      title: title,
      category: category,
      payerName: payerName,
      participants: participants,
      date: extractedDate,
    );
  }

  String _stripTrailingPunctuation(String s) =>
      s.replaceFirst(_trailingPunctuationRegExp, '').trim();

  String _inferCategory(String text) {
    var best = 'Other';
    var bestScore = 0;
    for (final entry in _categoryKeywordRegexes.entries) {
      var score = 0;
      for (final regex in entry.value) {
        if (regex.hasMatch(text)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return best;
  }
}
