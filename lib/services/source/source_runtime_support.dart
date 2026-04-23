part of '../hazuki_source_service.dart';

extension HazukiSourceServiceSourceRuntimeSupport on HazukiSourceService {
  SourceRuntimeState get runtimeState => facade.runtimeState;

  Future<void> prewarmInBackground() async {
    if (isInitialized) {
      return;
    }
    final facade = this.facade;
    final inFlight = facade.initFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    facade.addApplicationLog(
      level: 'info',
      title: 'Source prewarm scheduled',
      source: 'source_runtime',
      content: {
        'phase': facade.runtimeState.phase.name,
        'statusText': facade.statusText,
      },
    );

    await init(prewarm: true);

    facade.addApplicationLog(
      level: isInitialized ? 'info' : 'warning',
      title: isInitialized
          ? 'Source prewarm completed'
          : 'Source prewarm failed',
      source: 'source_runtime',
      content: runtimeState.toDebugMap(),
    );
  }

  bool isSourceRuntimeRelatedError(Object? error) {
    final raw = (error ?? '').toString().trim().toLowerCase();
    if (raw.isEmpty) {
      return false;
    }
    return raw.contains('source_not_initialized') ||
        raw.contains('source_init_failed') ||
        raw.contains('source_download_failed_without_cache') ||
        raw.contains('source_metadata_incomplete') ||
        raw.contains('module handler timeout') ||
        raw.contains('module not found') ||
        raw.contains('discover_load_timeout') ||
        raw.contains('search timeout') ||
        raw.contains('favorite') && raw.contains('timed out');
  }

  void logRuntimeRetryRequested(String source) {
    final facade = this.facade;
    facade.addApplicationLog(
      level: 'info',
      title: 'Source retry requested',
      source: 'source_runtime',
      content: {
        'trigger': source,
        'phase': facade.runtimeState.phase.name,
        'step': facade.runtimeState.step.name,
        'statusText': facade.statusText,
      },
    );
  }

  void _setRuntimeState({
    required SourceRuntimePhase phase,
    SourceRuntimeStep step = SourceRuntimeStep.none,
    String? statusText,
    String? debugDetail,
    Object? error,
  }) {
    final next = SourceRuntimeState(
      phase: phase,
      step: step,
      statusText: statusText ?? facade.statusText,
      updatedAt: DateTime.now(),
      debugDetail: debugDetail,
      error: error?.toString(),
    );
    facade.runtimeState = next;
    facade.statusText = next.statusText;
    facade.notifyRuntimeStateChanged();
  }

  void _setRuntimeBusyState(
    SourceRuntimePhase phase,
    SourceRuntimeStep step, {
    String? debugDetail,
    String? statusText,
  }) {
    _setRuntimeState(
      phase: phase,
      step: step,
      statusText: statusText,
      debugDetail: debugDetail,
    );
  }

  void _setRuntimeReadyState({
    required _SourceLoadResult result,
    required SourceMeta meta,
  }) {
    _setRuntimeState(
      phase: SourceRuntimePhase.ready,
      step: SourceRuntimeStep.none,
      statusText: '${result.message}|${meta.name}|${meta.key}|${meta.version}',
      debugDetail: 'ready',
    );
  }

  void _setRuntimeFailedState(Object error, {SourceRuntimeStep? step}) {
    final failedStep = step ?? facade.runtimeState.step;
    _setRuntimeState(
      phase: SourceRuntimePhase.failed,
      step: failedStep,
      statusText: 'source_init_failed:$error',
      debugDetail: failedStep.name,
      error: error,
    );
    facade.addApplicationLog(
      level: 'warning',
      title: 'Source runtime failed',
      source: 'source_runtime',
      content: runtimeState.toDebugMap(),
    );
  }

  void _setRuntimeWaitingForRestartState({
    required String statusText,
    String? debugDetail,
  }) {
    _setRuntimeState(
      phase: SourceRuntimePhase.waitingForRestart,
      step: SourceRuntimeStep.none,
      statusText: statusText,
      debugDetail: debugDetail,
    );
    facade.addApplicationLog(
      level: 'info',
      title: 'Source runtime waiting for restart',
      source: 'source_runtime',
      content: runtimeState.toDebugMap(),
    );
  }
}
