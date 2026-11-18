import 'dart:convert';

import 'package:quickjs_engine/quickjs_engine.dart';

import '../../logging/app_log_event.dart';
import '../../logging/app_log_sanitizer.dart';
import '../../logging/app_log_store.dart';
import '../models/source_task.dart';
import '../runtime/source_task_registry.dart';

class SourceTaskLogRecorder {
  const SourceTaskLogRecorder(this.store);

  final AppLogStore store;

  static const _terminalStates = {
    SourceTaskState.succeeded,
    SourceTaskState.failed,
    SourceTaskState.cancelled,
    SourceTaskState.timedOut,
  };

  void record(
    SourceTaskSnapshot task,
    SourceTaskEvent event,
    SourceTaskResultDisposition disposition,
    Object? error,
    StackTrace? stack, {
    Iterable<String> sensitiveValues = const [],
  }) {
    if (!store.captureEnabled) return;
    final discarded = event == SourceTaskEvent.resultDiscarded;
    final settled = event == SourceTaskEvent.resourcesSettled;
    // 每个来源任务都会经历多次状态切换；中间态与正常完成的资源回收不含诊断价值，
    // 只记录终态以及异常结束后的资源回收，避免日志被任务流水淹没。
    if (!discarded && !settled && !_terminalStates.contains(task.state)) {
      return;
    }
    if (settled && task.state == SourceTaskState.succeeded) return;
    // Task capture excludes search text even when exports keep all other data.
    String redact(String value) {
      var text = value;
      for (final secret in sensitiveValues.where((s) => s.isNotEmpty)) {
        final json = jsonEncode(secret);
        for (final form in {
          secret,
          Uri.encodeComponent(secret),
          Uri.encodeQueryComponent(secret),
          json.substring(1, json.length - 1),
        }.toList()..sort((a, b) => b.length.compareTo(a.length))) {
          text = text.replaceAll(form, '[hidden]');
        }
      }
      return text;
    }

    final data = <String, Object?>{
      ...task.toJson(),
      if (discarded) 'resultDisposition': disposition.name,
      if (error != null) ...{
        'errorType': error.runtimeType.toString(),
        // Never include the evaluated expression or plugin arguments.
        'error': redact(error is JSError ? error.message : error.toString()),
        if (error is JSError) 'scriptStack': redact(error.stack),
        if (stack != null) 'stack': redact(stack.toString()),
      },
    };

    store.add(
      level: discarded || settled
          ? 'debug'
          : switch (task.state) {
              SourceTaskState.failed => 'error',
              SourceTaskState.timedOut => 'warning',
              _ => 'debug',
            },
      area: AppLogArea.source,
      source: 'source_task',
      event: discarded
          ? 'source_task_result_discarded'
          : settled
          ? 'source_task_resources_settled'
          : 'source_task_${task.state.name}',
      title: discarded
          ? 'Source task result discarded'
          : settled
          ? 'Source task resources settled'
          : 'Source task ${task.state.name}',
      data: const AppLogSanitizer().sanitize(
        data,
        AppLogSanitization.hideAllSensitive,
      ),
    );
  }
}
