import 'package:flutter/foundation.dart';

import '../../hazuki_source_service.dart';

abstract class HazukiSourceAdapterBase {
  const HazukiSourceAdapterBase(this.source);

  @protected
  final HazukiSourceService source;
}

abstract class HazukiSourceListenableAdapter extends HazukiSourceAdapterBase
    implements Listenable {
  const HazukiSourceListenableAdapter(super.source);

  @override
  void addListener(VoidCallback listener) => source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => source.removeListener(listener);
}
