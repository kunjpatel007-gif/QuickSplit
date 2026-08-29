import 'package:flutter_test/flutter_test.dart';
import 'package:campus_quicksplit/domain/services/services.dart';

void main() {
  final parser = NlpParser();

  group('pro-rata parsing', () {
    test('splits items and sums a single tax mention', () {
      final result = parser.parse(
        'I ordered pizza for 500 and Kunj ordered pasta for 600, the taxes were 120',
      );
      expect(result.isProRata, isTrue);
      expect(result.items.length, 2);
      expect(result.items[0].person, 'I');
      expect(result.items[0].item, 'pizza');
      expect(result.items[0].amount, 500.0);
      expect(result.items[1].person, 'Kunj');
      expect(result.taxAmount, 120.0);
      expect(result.amount, 1220.0);
      expect(result.category, 'Food');
    });

    test('sums multiple separate tax/tip mentions', () {
      final result = parser.parse('I ordered coffee for 100, tax 10 and tip 15');
      expect(result.isProRata, isTrue);
      expect(result.taxAmount, 25.0);
      expect(result.amount, 125.0);
    });

    test('handles comma-grouped amounts', () {
      final result = parser.parse('Kunj ordered shoes for 1,200');
      expect(result.isProRata, isTrue);
      expect(result.items.single.amount, 1200.0);
      expect(result.amount, 1200.0);
    });

    test('falls back to no-"for" phrasing', () {
      final result = parser.parse('I got coffee 100');
      expect(result.isProRata, isTrue);
      expect(result.items.single.item, 'coffee');
      expect(result.items.single.amount, 100.0);
    });

    test('defaults missing subject to "I"', () {
      final result = parser.parse('ordered a pizza for 500');
      expect(result.items.single.person, 'I');
      expect(result.items.single.item, 'pizza'); // leading article stripped
    });
  });

  group('standard parsing', () {
    test('extracts amount, title, category and participants', () {
      final result = parser.parse('Lunch 500 with Kunj and Mitul');
      expect(result.isProRata, isFalse);
      expect(result.amount, 500.0);
      expect(result.category, 'Food');
      expect(result.participants, containsAll(['Kunj', 'Mitul']));
    });

    test('extracts payer via "X paid"', () {
      final result = parser.parse('Mitul paid 300 for Uber with Kunj');
      expect(result.payerName, 'Mitul');
      expect(result.title, 'Uber');
      expect(result.category, 'Transport');
    });

    test('extracts payer via "paid by X"', () {
      final result = parser.parse('300 for Uber paid by Mitul');
      expect(result.payerName, 'Mitul');
    });

    test('does not mistake "cab" inside "cabbage" for Transport', () {
      final result = parser.parse('cabbage for 80');
      expect(result.category, isNot('Transport'));
    });

    test('handles comma-grouped amounts without a currency symbol', () {
      final result = parser.parse('Flight tickets 12,500 with Kunj');
      expect(result.amount, 12500.0);
    });

    test('falls back to a stripped title when there is no "for" clause', () {
      final result = parser.parse('Mitul paid 300 with Kunj');
      expect(result.title, isNotNull);
      expect(result.title, isNot(contains('300')));
    });
  });

  group('robustness', () {
    test('never throws on empty or partial input', () {
      expect(() => parser.parse(''), returnsNormally);
      expect(() => parser.parse('   '), returnsNormally);
      expect(() => parser.parse('I ordered'), returnsNormally);
      expect(() => parser.parse('paid'), returnsNormally);
      expect(() => parser.parse('for with and'), returnsNormally);
    });
  });
}
