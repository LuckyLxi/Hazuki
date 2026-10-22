import 'dart:async';

import '../models/source_task.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';
import 'source_runtime_state_controller.dart';

/// 运行时故障判定后的宿主侧处理：记录诊断、置为失败，并按单次额度恢复。
///
/// 恢复在原 handle 上用现有共享初始化重建新实例，不重放任何已接纳操作；
/// 活动来源立即恢复，仅由租约保留的非活动来源等下一次新调用惰性重建。
class SourceRuntimeHealthMonitor {
  SourceRuntimeHealthMonitor({
    required SourceRuntimeHost runtimeHost,
    required SourceRuntimeStateController runtimeStateController,
    required Future<void> Function(String sourceKey) ensureSourceInitialized,
  }) : _runtimeHost = runtimeHost,
       _runtimeStateController = runtimeStateController,
       _ensureSourceInitialized = ensureSourceInitialized;

  final SourceRuntimeHost _runtimeHost;
  final SourceRuntimeStateController _runtimeStateController;
  final Future<void> Function(String sourceKey) _ensureSourceInitialized;

  void handleFailure(
    SourceRuntimeHandle handle,
    SourceRuntimeFailed failure, {
    required bool recover,
  }) {
    final active =
        _runtimeHost.isCurrentHandle(handle) &&
        _runtimeHost.activeSourceKey == handle.sourceKey;
    _runtimeStateController.setFailed(handle.facade, failure);
    _log(
      handle,
      failure,
      !recover
          ? 'latched'
          : active
          ? 'recovering'
          : 'deferred',
    );
    if (!recover || !active) return;
    unawaited(_recover(handle, failure));
  }

  Future<void> _recover(
    SourceRuntimeHandle handle,
    SourceRuntimeFailed failure,
  ) async {
    try {
      await _ensureSourceInitialized(handle.sourceKey);
    } catch (_) {
      // 失败状态已由初始化流程记录；这里只补充恢复结果。
    }
    if (handle.isDisposalRequested) return;
    _log(
      handle,
      failure,
      handle.runtime.engine != null ? 'recovered' : 'recoveryFailed',
    );
  }

  void _log(
    SourceRuntimeHandle handle,
    SourceRuntimeFailed failure,
    String recovery,
  ) {
    try {
      handle.facade.addApplicationLog(
        level: 'warning',
        title: 'Source runtime failure',
        source: 'source_runtime',
        content: {
          'sourceKey': handle.sourceKey,
          'runtimeId': failure.runtimeId,
          'kind': failure.kind.name,
          'recovery': recovery,
        },
      );
    } catch (_) {
      // 诊断不能改变故障处理。
    }
  }
}
