import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/state/discover_page_controller.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('forwards source service changes until disposed', () {
    final controller = DiscoverPageController();
    var notifications = 0;
    controller.addListener(() {
      notifications++;
    });

    // ignore: invalid_use_of_protected_member
    HazukiSourceService.instance.notifyListeners();

    expect(notifications, 1);

    controller.dispose();
    // ignore: invalid_use_of_protected_member
    HazukiSourceService.instance.notifyListeners();

    expect(notifications, 1);
  });
}
