import '../../../models/source_meta.dart';
import '../models/source_contract_models.dart';
import 'source_runtime_facade.dart';

/// Owns runtime-state transitions and their associated diagnostic logs.
class SourceRuntimeStateController {
  void setState({
    required HazukiSourceFacade facade,
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

  void setBusy(
    HazukiSourceFacade facade,
    SourceRuntimePhase phase,
    SourceRuntimeStep step, {
    String? debugDetail,
    String? statusText,
  }) => setState(
    facade: facade,
    phase: phase,
    step: step,
    statusText: statusText,
    debugDetail: debugDetail,
  );

  void setReady(
    HazukiSourceFacade facade, {
    required String message,
    required SourceMeta meta,
  }) => setState(
    facade: facade,
    phase: SourceRuntimePhase.ready,
    statusText: '$message|${meta.name}|${meta.key}|${meta.version}',
    debugDetail: 'ready',
  );

  void setFailed(
    HazukiSourceFacade facade,
    Object error, {
    SourceRuntimeStep? step,
  }) {
    final failedStep = step ?? facade.runtimeState.step;
    setState(
      facade: facade,
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
      content: facade.runtimeState.toDebugMap(),
    );
  }

  void setWaitingForRestart(
    HazukiSourceFacade facade, {
    required String statusText,
    String? debugDetail,
  }) {
    setState(
      facade: facade,
      phase: SourceRuntimePhase.waitingForRestart,
      statusText: statusText,
      debugDetail: debugDetail,
    );
    facade.addApplicationLog(
      level: 'info',
      title: 'Source runtime waiting for restart',
      source: 'source_runtime',
      content: facade.runtimeState.toDebugMap(),
    );
  }
}
