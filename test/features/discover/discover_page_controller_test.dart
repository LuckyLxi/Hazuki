import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/discover/state/discover_page_controller.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await ensureTestServiceLocator();
  });

  test('forwards source service changes until disposed', () {
    final controller = DiscoverPageController(
      sourceService: sl<SourceDiscoverGateway>(),
    );
    var notifications = 0;
    controller.addListener(() {
      notifications++;
    });

    // ignore: invalid_use_of_protected_member
    sl<SourceRuntimeAssembly>().testing.notifyRuntimeView();

    expect(notifications, 1);

    controller.dispose();
    // ignore: invalid_use_of_protected_member
    sl<SourceRuntimeAssembly>().testing.notifyRuntimeView();

    expect(notifications, 1);
  });
}
