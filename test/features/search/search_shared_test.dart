import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

void main() {
  final rules = DirectComicIdRules.parse({
    'patterns': [r'^(?:jm)?(\d{2,})$'],
    'extractDigits': true,
  })!;

  test('plugin rules normalize IDs and require a complete keyword match', () {
    expect(rules.match('12345'), '12345');
    expect(rules.match(' JM12345 '), '12345');
    expect(rules.match('abc123def'), isNull);
    expect(rules.match('1'), isNull);
    final unanchored = DirectComicIdRules.parse({
      'patterns': [r'(\d+)'],
      'extractDigits': false,
    })!;
    expect(unanchored.match('abc123'), isNull);
    expect(unanchored.match('123'), '123');
  });

  test('rules apply in declaration order and skip empty captures', () {
    final ordered = DirectComicIdRules.parse({
      'patterns': [r'(a)?123', r'(12)3', r'(123)'],
      'extractDigits': false,
    })!;
    expect(ordered.match('123'), '12');
  });

  test('digit enhancement requires opt-in and three digits in mixed text', () {
    expect(rules.extract(' abc123def '), '123');
    expect(rules.extract('abc12def'), isNull);
    expect(rules.extract(' 123 '), isNull);
    expect(rules.extract(''), isNull);
    final disabled = DirectComicIdRules.parse({
      'patterns': [r'(\d+)'],
      'extractDigits': false,
    })!;
    expect(disabled.extract('abc123def'), isNull);
  });
}
