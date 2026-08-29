import 'package:flutter_test/flutter_test.dart';
import 'package:campus_quicksplit/domain/services/nlp_parser.dart';
void main() {
  test('nlp bug', () async {
    final p = NlpParser();
    final r = await p.parse('i ordered icecream for 50 kunj ordered sandwich for 100 taxes 25');
    print('Total: ' + r.amount.toString() + ' Tax: ' + r.taxAmount.toString());
    for (var i in r.items) {
      print(i.person + ': ' + i.amount.toString());
    }
  });
}