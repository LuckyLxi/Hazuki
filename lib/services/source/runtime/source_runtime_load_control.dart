import '../models/source_script_execution.dart';
import 'source_script_engine.dart';

/// Host-only control for a privately owned runtime candidate.
class SourceRuntimeLoadControl {
  const SourceRuntimeLoadControl({
    required this.execution,
    required this.checkActive,
    required this.bindEngine,
  });
  final SourceScriptExecution execution;
  final void Function() checkActive;
  final void Function(SourceScriptEngine) bindEngine;

  Future<dynamic> evaluate(
    SourceScriptEngine engine,
    String code, {
    String? name,
  }) async {
    checkActive();
    final value = await engine.evaluate(code, name: name, execution: execution);
    checkActive();
    return value;
  }

  Future<void> execute(
    SourceScriptEngine engine,
    String code, {
    String? name,
  }) async {
    checkActive();
    await engine.execute(code, name: name, execution: execution);
    checkActive();
  }
}
