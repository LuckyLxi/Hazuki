// Runs against the native bridge built by `sh tool/build_native.sh`
// (native/build/), or the library named by LIBQUICKJSC_TEST_PATH. See
// "Tests can't find the dylib" in the README.
import 'package:flutter_test/flutter_test.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

const _mapJoin = '[1,2,3].map(x=>x*2).join(",")';

void main() {
  test('evaluates JavaScript without a memory limit', () {
    final runtime = QuickJsRuntime2();
    addTearDown(runtime.dispose);

    final result = runtime.evaluate(_mapJoin);

    expect(result.isError, isFalse, reason: result.stringResult);
    expect(result.stringResult, '2,4,6');
  });

  test('evaluates JavaScript with a memory limit', () {
    final runtime = QuickJsRuntime2(memoryLimit: 32 * 1024 * 1024);
    addTearDown(runtime.dispose);

    final result = runtime.evaluate(_mapJoin);

    expect(result.isError, isFalse, reason: result.stringResult);
    expect(result.stringResult, '2,4,6');
  });

  test('enforces the memory limit', () {
    const allocate64MiB = 'new ArrayBuffer(64 * 1024 * 1024).byteLength';

    final unlimited = QuickJsRuntime2();
    addTearDown(unlimited.dispose);
    final unlimitedResult = unlimited.evaluate(allocate64MiB);
    expect(
      unlimitedResult.isError,
      isFalse,
      reason: unlimitedResult.stringResult,
    );
    expect(unlimitedResult.stringResult, '${64 * 1024 * 1024}');

    final limited = QuickJsRuntime2(memoryLimit: 16 * 1024 * 1024);
    addTearDown(limited.dispose);
    final limitedResult = limited.evaluate(allocate64MiB);
    expect(
      limitedResult.isError,
      isTrue,
      reason: 'a 64 MiB allocation must fail under a 16 MiB limit',
    );
    expect(limitedResult.stringResult, contains('out of memory'));

    // The runtime stays usable after hitting the limit.
    expect(limited.evaluate(_mapJoin).stringResult, '2,4,6');
  });
}
