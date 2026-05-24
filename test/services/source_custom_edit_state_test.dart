import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
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

    final sourceService = sl<HazukiSourceService>();
    expect(await sourceService.hasCustomEditedActiveSource(), isFalse);

    await sourceService.activateSource('copy_manga');
    expect(await sourceService.hasCustomEditedActiveSource(), isTrue);
  });

  test('legacy custom edited JM flag only applies to JM source', () async {
    SharedPreferences.setMockInitialValues({
      SourcePrefsKeys.customEditedJmSource: true,
    });

    final sourceService = sl<HazukiSourceService>();
    expect(await sourceService.hasCustomEditedSource('jm'), isTrue);
    expect(await sourceService.hasCustomEditedSource('copy_manga'), isFalse);
  });
}
