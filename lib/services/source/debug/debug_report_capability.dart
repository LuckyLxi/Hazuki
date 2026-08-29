import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../../logging/app_log_event.dart';
import '../../logging/app_log_store.dart';
import '../runtime/source_runtime_facade.dart';

class SourceDebugReportCapability {
  SourceDebugReportCapability({
    required HazukiSourceFacade Function() activeFacade,
    required String? Function() currentAccount,
    required AppLogStore logStore,
  }) : _activeFacade = activeFacade,
       _currentAccount = currentAccount,
       _logStore = logStore;

  final HazukiSourceFacade Function() _activeFacade;
  final String? Function() _currentAccount;
  final AppLogStore _logStore;
  late final Future<String> _appVersion = _loadAppVersion();

  Future<Map<String, dynamic>> collectAllDebugInfo() =>
      _buildReport(_logStore.events, reportType: 'all');

  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) {
    final normalized = type.trim().toLowerCase();
    final logs = _logStore.events.where((event) {
      return switch (normalized) {
        'error' => event.level == AppLogLevel.error,
        'performance' => event.tags.contains('performance'),
        'system' =>
          event.area == AppLogArea.source ||
              event.area == AppLogArea.network ||
              event.area == AppLogArea.update,
        'action' =>
          event.area == AppLogArea.application ||
              event.area == AppLogArea.reader ||
              event.area == AppLogArea.download,
        _ => true,
      };
    });
    return _buildReport(logs, reportType: normalized);
  }

  Future<Map<String, dynamic>> collectNetworkDebugInfo() async {
    final report = await _buildReport(
      _logStore.events.where((event) => event.area == AppLogArea.network),
      reportType: 'network',
    );
    return <String, dynamic>{...report, 'recentNetworkLogs': report['logs']};
  }

  Future<Map<String, dynamic>> collectApplicationDebugInfo() async {
    final report = await _buildReport(
      _logStore.events.where((event) => event.area == AppLogArea.application),
      reportType: 'application',
    );
    return <String, dynamic>{
      ...report,
      'recentApplicationLogs': report['logs'],
    };
  }

  Future<Map<String, dynamic>> collectReaderDebugInfo() async {
    final report = await _buildReport(
      _logStore.events.where((event) => event.area == AppLogArea.reader),
      reportType: 'reader',
    );
    return <String, dynamic>{...report, 'recentReaderLogs': report['logs']};
  }

  Future<Map<String, dynamic>> _buildReport(
    Iterable<AppLogEvent> events, {
    required String reportType,
  }) async {
    final facade = _activeFacade();
    final logs = events.map((event) => event.toJson()).toList(growable: false);
    final appVersion = await _appVersion;
    return <String, dynamic>{
      'formatVersion': 2,
      'type': reportType,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': _logStore.captureEnabled,
      'platform': Platform.operatingSystem,
      'appVersion': appVersion,
      'statusText': facade.statusText,
      'sourceRuntimeState': facade.runtimeState.toDebugMap(),
      'sourceMeta': <String, dynamic>{
        'name': facade.sourceMeta?.name,
        'key': facade.sourceMeta?.key,
        'version': facade.sourceMeta?.version,
      },
      'currentAccount': _currentAccount(),
      'logStats': <String, dynamic>{
        'keptCount': logs.length,
        'errorCount': logs
            .where((log) => log['level'] == AppLogLevel.error.wireName)
            .length,
        'warningCount': logs
            .where((log) => log['level'] == AppLogLevel.warning.wireName)
            .length,
      },
      'logs': logs,
    };
  }

  Future<String> _loadAppVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Package metadata is unavailable in some isolated test environments.
      return '-';
    }
  }
}
