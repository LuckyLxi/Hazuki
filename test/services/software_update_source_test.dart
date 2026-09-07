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

  test('software update source persists ghproxy selection', () async {
    final service = SoftwareUpdateService();

    await service.setUpdateSource(SoftwareUpdateSource.ghproxy);

    expect(await service.loadUpdateSource(), SoftwareUpdateSource.ghproxy);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(hazukiSoftwareUpdateSourcePreferenceKey), 'ghproxy');
  });

  test('software update check URL follows the selected source', () {
    expect(
      resolveSoftwareUpdateCheckUrl(SoftwareUpdateSource.jsDelivr),
      'https://cdn.jsdelivr.net/gh/LuckyLxi/Hazuki@main/update.json',
    );
    expect(
      resolveSoftwareUpdateCheckUrl(SoftwareUpdateSource.github),
      'https://api.github.com/repos/LuckyLxi/Hazuki/releases/latest',
    );
    expect(
      resolveSoftwareUpdateCheckUrl(SoftwareUpdateSource.ghproxy),
      'https://ghproxy.net/https://raw.githubusercontent.com/LuckyLxi/Hazuki/main/update.json',
    );
  });

  test('ghproxy source proxies GitHub package URLs', () {
    const packageUrl =
        'https://github.com/example/project/releases/download/latest/app.apk';

    expect(
      resolveSoftwareUpdateDownloadUrl(
        packageUrl,
        SoftwareUpdateSource.ghproxy,
      ),
      'https://ghproxy.net/$packageUrl',
    );
  });

  test('ghproxy source does not proxy other hosts or duplicate its prefix', () {
    const proxiedUrl =
        'https://ghproxy.net/https://github.com/example/project/releases/download/latest/app.apk';

    expect(
      resolveSoftwareUpdateDownloadUrl(
        'https://example.com/app-release.apk',
        SoftwareUpdateSource.ghproxy,
      ),
      'https://example.com/app-release.apk',
    );
    expect(
      resolveSoftwareUpdateDownloadUrl(
        proxiedUrl,
        SoftwareUpdateSource.ghproxy,
      ),
      proxiedUrl,
    );
  });

  test('unknown software update source falls back to jsDelivr', () async {
    SharedPreferences.setMockInitialValues({
      hazukiSoftwareUpdateSourcePreferenceKey: 'unknown',
    });
    final service = SoftwareUpdateService();

    expect(await service.loadUpdateSource(), SoftwareUpdateSource.jsDelivr);
  });
}
