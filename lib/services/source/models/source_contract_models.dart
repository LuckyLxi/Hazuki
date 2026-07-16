import 'package:flutter/foundation.dart';

class SourceCatalogEntry {
  const SourceCatalogEntry({
    required this.key,
    required this.name,
    required this.fileName,
    this.directUrls = const [],
  });

  final String key;
  final String name;
  final String fileName;
  final List<String> directUrls;

  String get normalizedKey => key.trim();
  String get normalizedFileName => fileName.trim();

  bool matchesIndexEntry(Map<String, dynamic> map) {
    final indexKey = map['key']?.toString().trim();
    final indexFileName = map['fileName']?.toString().trim();
    return indexKey == normalizedKey ||
        (indexFileName?.toLowerCase() == normalizedFileName.toLowerCase());
  }

  List<String> fallbackUrls() {
    if (directUrls.isNotEmpty) {
      return directUrls;
    }
    final file = normalizedFileName;
    if (file.isEmpty) {
      return const [];
    }
    return ['https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/$file'];
  }
}

enum DailyCheckInStatus { success, alreadyCheckedIn, skipped }

class DailyCheckInResult {
  const DailyCheckInResult._(this.status, [this.message]);

  const DailyCheckInResult.success([String? message])
    : this._(DailyCheckInStatus.success, message);

  const DailyCheckInResult.alreadyCheckedIn([String? message])
    : this._(DailyCheckInStatus.alreadyCheckedIn, message);

  const DailyCheckInResult.skipped([String? message])
    : this._(DailyCheckInStatus.skipped, message);

  final DailyCheckInStatus status;
  final String? message;

  bool get isSuccess => status == DailyCheckInStatus.success;
  bool get isAlreadyCheckedIn => status == DailyCheckInStatus.alreadyCheckedIn;
  bool get isSkipped => status == DailyCheckInStatus.skipped;
}

enum SourceRuntimePhase {
  idle,
  prewarming,
  loading,
  ready,
  failed,
  retrying,
  waitingForRestart,
}

enum SourceRuntimeStep {
  none,
  loadingCache,
  downloadingSource,
  creatingEngine,
  runningSourceInit,
}

@immutable
class SourceRuntimeState {
  const SourceRuntimeState({
    required this.phase,
    required this.step,
    required this.statusText,
    required this.updatedAt,
    this.debugDetail,
    this.error,
  });

  const SourceRuntimeState.idle()
    : this(
        phase: SourceRuntimePhase.idle,
        step: SourceRuntimeStep.none,
        statusText: 'source_idle',
        updatedAt: null,
      );

  final SourceRuntimePhase phase;
  final SourceRuntimeStep step;
  final String statusText;
  final DateTime? updatedAt;
  final String? debugDetail;
  final String? error;

  bool get isBusy =>
      phase == SourceRuntimePhase.prewarming ||
      phase == SourceRuntimePhase.loading ||
      phase == SourceRuntimePhase.retrying;
  bool get isReady => phase == SourceRuntimePhase.ready;
  bool get hasFailure => phase == SourceRuntimePhase.failed;
  bool get canRetry => phase == SourceRuntimePhase.failed;
  bool get isWaitingForRestart => phase == SourceRuntimePhase.waitingForRestart;
  bool get shouldSurfaceOnPage => isBusy || hasFailure || isWaitingForRestart;

  Map<String, dynamic> toDebugMap() {
    return <String, dynamic>{
      'phase': phase.name,
      'step': step.name,
      'statusText': statusText,
      'updatedAt': updatedAt?.toIso8601String(),
      'debugDetail': debugDetail,
      'error': error,
      'canRetry': canRetry,
      'shouldSurfaceOnPage': shouldSurfaceOnPage,
    };
  }
}

class PreparedChapterImageData {
  const PreparedChapterImageData({
    required this.bytes,
    required this.extension,
    required this.wasProcessed,
    this.aspectRatio,
  });

  final Uint8List bytes;
  final String extension;
  final bool wasProcessed;
  final double? aspectRatio;
}

class SourceVersionCheckResult {
  const SourceVersionCheckResult({
    required this.sourceKey,
    required this.sourceName,
    required this.localVersion,
    required this.remoteVersion,
    required this.hasUpdate,
  });

  final String sourceKey;
  final String sourceName;
  final String localVersion;
  final String remoteVersion;
  final bool hasUpdate;
}
