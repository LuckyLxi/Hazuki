import 'package:flutter/widgets.dart';
import '../../services/cloud_sync_service.dart';

abstract interface class CloudSyncRestoreHandler {
  Future<void> applyCloudSyncRestore(CloudSyncRestoreResult result);
}

class HazukiAppControllerScope extends InheritedWidget {
  const HazukiAppControllerScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final CloudSyncRestoreHandler controller;

  static CloudSyncRestoreHandler of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<HazukiAppControllerScope>();
    assert(scope != null, 'HazukiAppControllerScope is missing.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(HazukiAppControllerScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
