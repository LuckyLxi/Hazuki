import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('software update source defaults to jsDelivr', () async {
    final service = SoftwareUpdateService();

    expect(await service.loadUpdateSource(), SoftwareUpdateSource.jsDelivr);
  });

  test('software update source persists GitHub selection', () async {
    final service = SoftwareUpdateService();

    await service.setUpdateSource(SoftwareUpdateSource.github);

    expect(await service.loadUpdateSource(), SoftwareUpdateSource.github);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(hazukiSoftwareUpdateSourcePreferenceKey), 'github');
  });

  test('unknown software update source falls back to jsDelivr', () async {
    SharedPreferences.setMockInitialValues({
      hazukiSoftwareUpdateSourcePreferenceKey: 'unknown',
    });
    final service = SoftwareUpdateService();

    expect(await service.loadUpdateSource(), SoftwareUpdateSource.jsDelivr);
  });
}
