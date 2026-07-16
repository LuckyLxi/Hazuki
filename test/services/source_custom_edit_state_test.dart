import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/common/source_prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await ensureTestServiceLocator();
  });

  test('custom edited source flag is scoped to the active source', () async {
    SharedPreferences.setMockInitialValues({
      SourcePrefsKeys.customEditedSource('copy_manga'): true,
      SourcePrefsKeys.customEditedSource('jm'): false,
    });

    final sourceService = sl<SourceRuntimeAssembly>();
    expect(
      await sourceService.testing.runtimeOperations
          .hasCustomEditedActiveSource(),
      isFalse,
    );

    await sourceService.runtimeRegistry.activateSource('copy_manga');
    expect(
      await sourceService.testing.runtimeOperations
          .hasCustomEditedActiveSource(),
      isTrue,
    );
  });

  test('legacy custom edited JM flag only applies to JM source', () async {
    SharedPreferences.setMockInitialValues({
      SourcePrefsKeys.customEditedJmSource: true,
    });

    final sourceService = sl<SourceRuntimeAssembly>();
    expect(
      await sourceService.testing.runtimeOperations.hasCustomEditedSource('jm'),
      isTrue,
    );
    expect(
      await sourceService.testing.runtimeOperations.hasCustomEditedSource(
        'copy_manga',
      ),
      isFalse,
    );
  });
}
