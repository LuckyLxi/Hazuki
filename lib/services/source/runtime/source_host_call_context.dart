import 'dart:async';

import 'package:quickjs_engine/quickjs_engine.dart' show JSError;

import '../models/source_script_execution.dart';

class SourceScriptStopped extends JSError {
  SourceScriptStopped({
    required this.execution,
    required this.runtimeId,
    required this.nativeToken,
    required this.reason,
    this.timedOut = false,
    String? stack,
  }) : super(
         'source_script_stopped:$reason${timedOut ? ':interrupted' : ''}',
         stack,
       );
  final SourceScriptExecution execution;
  final String runtimeId;
  final int nativeToken;
  final String reason;
  final bool timedOut;
}

enum SourceScriptCancelStatus { accepted, alreadyRequested, notFound }

class SourceScriptCancelReceipt {
  SourceScriptCancelReceipt(this.status, this.whenSettled, this._shared);
  final SourceScriptCancelStatus status;
  final Future<void> whenSettled;
  final int Function() _shared;
  int get sharedResourceCount => _shared();
}

/// Host-only resource lifetime. The worker sends plain IDs, never this object.
class SourceHostCallContext {
  SourceHostCallContext({
    required this.execution,
    required this.runtimeId,
    required this.nativeToken,
    required this.workId,
    required this.resourceId,
  });
  final SourceScriptExecution execution;
  final String runtimeId;
  final int nativeToken;
  final int workId;
  final int resourceId;
  final Completer<void> _stopped = Completer<void>();
  SourceScriptStopped? _failure;

  /// Set before starting an authoritative write that cannot be interrupted.
  /// close waits for that write, while ordinary subscriptions can be detached.
  bool requiresDrain = false;

  /// Optional host-only authority check, also applied to delayed commits.
  void Function()? validateAuthority;
  int _pendingCommits = 0;
  Completer<void>? _commitsSettled;
  Future<void> get whenCommitsSettled =>
      _commitsSettled?.future ?? Future<void>.value();

  /// An HTTP cancellation may finish its subscription before a response
  /// interceptor finishes persisting cookies. Keep that commit in the lease.
  Future<T> runCommit<T>(Future<T> Function() action) async {
    checkActive();
    requiresDrain = true;
    if (_pendingCommits++ == 0) _commitsSettled = Completer<void>();
    try {
      return await action();
    } finally {
      if (--_pendingCommits == 0) _commitsSettled!.complete();
    }
  }

  bool get isStopped => _failure != null;
  Future<void> get whenStopped => _stopped.future;
  void checkActive() {
    if (_failure case final error?) throw error;
    validateAuthority?.call();
  }

  void stop(SourceScriptStopped error) {
    if (_failure != null) return;
    _failure = error;
    _stopped.complete();
  }
}
