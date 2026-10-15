import 'source_script_engine.dart';

import '../../../models/source_meta.dart';
import '../models/source_contract_models.dart';

class SourceRuntimeKernel {
  SourceScriptEngine? engine;
  Future<void>? initFuture;
  String statusText = 'source_idle';
  SourceRuntimeState runtimeState = const SourceRuntimeState.idle();
  SourceMeta? sourceMeta;
  bool isRefreshingSource = false;
  DateTime? lastReloginAt;
  String? transientAvatarUrl;

  bool shouldSkipRelogin(Duration minInterval) {
    final last = lastReloginAt;
    return last != null && DateTime.now().difference(last) < minInterval;
  }
}
