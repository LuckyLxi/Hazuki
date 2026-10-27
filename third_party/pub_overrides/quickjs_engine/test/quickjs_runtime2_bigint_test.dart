import 'package:flutter_test/flutter_test.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

void main() {
  test('BigInt typed arrays preserve short and full integer boundaries', () {
    final runtime = QuickJsRuntime2();
    addTearDown(runtime.dispose);

    const cases = {
      'BigInt64Array': [
        '-9223372036854775808',
        '-2147483649',
        '-2147483648',
        '-1',
        '0',
        '2147483647',
        '2147483648',
        '9223372036854775807',
      ],
      'BigUint64Array': [
        '0',
        '2147483647',
        '2147483648',
        '4294967295',
        '18446744073709551615',
      ],
    };
    for (final entry in cases.entries) {
      final literals = entry.value.map((value) => '${value}n').join(',');
      final result = runtime.evaluate(
        'Array.from(new ${entry.key}([$literals]), '
        '(value) => value.toString()).join(",")',
      );
      expect(result.isError, isFalse, reason: result.stringResult);
      expect(result.stringResult, entry.value.join(','), reason: entry.key);
    }
  });
}
