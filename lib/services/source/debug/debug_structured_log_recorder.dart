import '../../logging/app_log_event.dart';
import '../../logging/app_log_store.dart';
import 'debug_log_internals.dart';

class DebugStructuredLogRecorder {
  const DebugStructuredLogRecorder(this.store);

  final AppLogStore store;

  void addTyped({
    required String type,
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {
    final normalizedType = type.trim().toLowerCase();
    store.add(
      level: normalizedType == debugLogTypeError ? 'error' : level,
      area: inferLogArea(source: source, category: normalizedType),
      source: source,
      event: _eventName(title),
      title: title,
      data: content,
      tags: normalizedType == debugLogTypePerformance
          ? const <String>['performance']
          : const <String>[],
    );
  }

  void addApplication({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {
    store.add(
      level: level,
      area: inferLogArea(source: source),
      source: source,
      event: _eventName(title),
      title: title,
      data: content,
    );
  }

  void addReader({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) {
    store.add(
      level: level,
      area: AppLogArea.reader,
      source: source,
      event: _eventName(title),
      title: title,
      data: content,
      tags:
          source.toLowerCase().contains('position') ||
              title.toLowerCase().contains('frame')
          ? const <String>['performance']
          : const <String>[],
    );
  }

  String _eventName(String title) {
    final normalized = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'log' : normalized;
  }
}
