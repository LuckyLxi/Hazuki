import 'package:flutter_test/flutter_test.dart';
import 'package:quickjs_engine/quickjs/ffi.dart' show runtimeOpaques;
import 'package:quickjs_engine/quickjs_engine.dart';

void main() {
  test('repeated runtime disposal releases Dart bridge registrations', () {
    final initialCount = runtimeOpaques.length;
    for (var i = 0; i < 3; i++) {
      final runtime = QuickJsRuntime2();
      try {
        expect(runtime.evaluate('1 + 1').rawResult, 2);
        expect(runtimeOpaques.length, initialCount + 1);
      } finally {
        runtime.dispose();
      }
      expect(runtimeOpaques.length, initialCount);
    }
  });
}
