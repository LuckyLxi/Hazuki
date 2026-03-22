import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('locale preference persists supported values', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('app_locale'), 'en');

    await prefs.setString('app_locale', 'zh');
    expect(prefs.getString('app_locale'), 'zh');

    await prefs.setString('app_locale', 'system');
    expect(prefs.getString('app_locale'), 'system');
  });
}
