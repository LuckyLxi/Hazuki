import 'package:flutter/foundation.dart';

import '../runtime/source_runtime_view.dart';

/// Shared listener forwarding for gateways that render active runtime state.
///
/// Non-listenable adapters deliberately do not have a common base: that keeps
/// their constructor surface limited to the operations they actually use.
abstract class HazukiSourceListenableAdapter implements Listenable {
  const HazukiSourceListenableAdapter(this.runtime);

  @protected
  final SourceRuntimeView runtime;

  @override
  void addListener(VoidCallback listener) => runtime.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      runtime.removeListener(listener);
}
