import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/services/source/runtime/source_config_url_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const jsDelivrUrl =
      'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/jm.js';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('selects jsDelivr source config URL', () {
    expect(
      resolveSourceConfigUrl(jsDelivrUrl, SoftwareUpdateSource.jsDelivr),
      jsDelivrUrl,
    );
  });

  test('selects direct GitHub source config URL', () {
    expect(
      resolveSourceConfigUrl(jsDelivrUrl, SoftwareUpdateSource.github),
      'https://raw.githubusercontent.com/venera-app/venera-configs/main/jm.js',
    );
  });

  test('selects ghproxy source config URL', () {
    expect(
      resolveSourceConfigUrl(jsDelivrUrl, SoftwareUpdateSource.ghproxy),
      'https://ghproxy.net/https://raw.githubusercontent.com/venera-app/venera-configs/main/jm.js',
    );
  });

  test('uses the persisted update link selection', () async {
    await SoftwareUpdateService().setUpdateSource(SoftwareUpdateSource.ghproxy);

    expect(await resolveSelectedSourceConfigUrls(const [jsDelivrUrl]), const [
      'https://ghproxy.net/https://raw.githubusercontent.com/venera-app/venera-configs/main/jm.js',
    ]);
  });
}
