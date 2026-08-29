import 'package:flutter_test/flutter_test.dart';
import 'package:campus_quicksplit/domain/services/services.dart';

void main() {
  final parser = NlpParser();

  group('pro-rata parsing', () {
    test('', () async {
      final result = await parser.parse(
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

    test('', () async {
      final result = await parser.parse('I ordered coffee for 100, tax 10 and tip 15');
      expect(result.isProRata, isTrue);
      expect(result.taxAmount, 25.0);
      expect(result.amount, 125.0);
    });

    test('', () async {
      final result = await parser.parse('Kunj ordered shoes for 1,200');
      expect(result.isProRata, isTrue);
      expect(result.items.single.amount, 1200.0);
      expect(result.amount, 1200.0);
    });

    test('', () async {
      final result = await parser.parse('I got coffee 100');
      expect(result.isProRata, isTrue);
      expect(result.items.single.item, 'coffee');
      expect(result.items.single.amount, 100.0);
    });

    test('', () async {
      final result = await parser.parse('ordered a pizza for 500');
      expect(result.items.single.person, 'I');
      expect(result.items.single.item, 'pizza'); // leading article stripped
    });
  });

  group('standard parsing', () {
    test('handles trailing tax words', () async {
      final result = await parser.parse('I ordered pasta for 600 and kunj ordered pizza for 800 and 125 taxes');
      expect(result.isProRata, isTrue);
      expect(result.amount, 1525.0);
      expect(result.taxAmount, 125.0);
    });

    test('ignores stopwords in names', () async {
      final result = await parser.parse('Lunch 500 with Kunj and Mitul');
      expect(result.amount, 500);
      expect(result.category, 'Food');
      expect(result.participants, containsAll(['Kunj', 'Mitul']));
    });

    test('multi-payer parsing pools amounts and handles tax', () async {
      final result = await parser.parse('I paid 500 and mitul paid 600 for pizza and 110 tax');
      expect(result.amount, 1210.0);
      expect(result.taxAmount, 110.0);
      expect(result.title?.toLowerCase(), 'pizza and 110 tax');
      expect(result.multiPayers['I'], 550.0);
      expect(result.multiPayers['mitul'], 660.0);
      expect(result.items.length, 2);
      expect(result.items.firstWhere((i) => i.person == 'I').amount, 500.0);
      expect(result.items.firstWhere((i) => i.person == 'mitul').amount, 600.0);
      expect(result.isProRata, isTrue);
      expect(result.participants, containsAll(['I', 'mitul']));
    });

    test('standard parsing picks up payer name', () async {
      final result = await parser.parse('Mitul paid 300 for Uber with Kunj');
      expect(result.payerName, 'Mitul');
      expect(result.title, 'Uber');
      expect(result.category, 'Transport');
    });

    test('', () async {
      final result = await parser.parse('300 for Uber paid by Mitul');
      expect(result.payerName, 'Mitul');
    });

    test('', () async {
      final result = await parser.parse('cabbage for 80');
      expect(result.category, isNot('Transport'));
    });

    test('', () async {
      final result = await parser.parse('Flight tickets 12,500 with Kunj');
      expect(result.amount, 12500.0);
    });

    test('', () async {
      final result = await parser.parse('Mitul paid 300 with Kunj');
      expect(result.title, isNotNull);
      expect(result.title, isNot(contains('300')));
    });
  });

  group('robustness', () {
    test('', () async {
      await expectLater(parser.parse(''), completes);
      await expectLater(parser.parse('   '), completes);
      await expectLater(parser.parse('I ordered'), completes);
      await expectLater(parser.parse('paid'), completes);
      await expectLater(parser.parse('for with and'), completes);
    });
  });
}
