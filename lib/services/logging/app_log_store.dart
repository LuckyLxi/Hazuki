import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

import 'app_log_event.dart';

abstract interface class AppLogSecretStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class AppLogStore extends ChangeNotifier {
  AppLogStore({
    AppLogSecretStorage? secureStorage,
    Future<Directory> Function()? supportDirectory,
  }) : _secureStorage = secureStorage,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static const Duration retention = Duration(days: 7);
  static const Duration duplicateWindow = Duration(minutes: 5);
  static const int maxPersistentBytes = 10 * 1024 * 1024;
  static const int maxPersistentEvents = 2000;
  static const int maxDisabledEvents = 200;
  static const String _encryptionKeyName = 'hazuki_log_encryption_key_v2';

  final AppLogSecretStorage? _secureStorage;
  final Future<Directory> Function() _supportDirectory;
  final List<AppLogEvent> _events = <AppLogEvent>[];
  Timer? _persistTimer;
  Future<void>? _persistFuture;
  bool _persistPending = false;
  int _persistenceGeneration = 0;
  bool _captureEnabled = false;
  bool _initialized = false;
  int _sequence = 0;

  bool get captureEnabled => _captureEnabled;
  List<AppLogEvent> get events => List.unmodifiable(_events);

  Future<void> initialize({required bool captureEnabled}) async {
    _captureEnabled = captureEnabled;
    if (_initialized) {
      if (!captureEnabled) await _deletePersistedLogs();
      notifyListeners();
      return;
    }
    _initialized = true;
    if (captureEnabled && _secureStorage != null) {
      await _loadPersistedLogs();
    } else {
      await _deletePersistedLogs();
    }
    await _deleteLegacyHistory();
    _prune();
    notifyListeners();
  }

  Future<void> setCaptureEnabled(bool enabled) async {
    if (_captureEnabled == enabled && _initialized) return;
    _captureEnabled = enabled;
    _initialized = true;
    if (!enabled) {
      _persistenceGeneration++;
      _events.removeWhere(
        (event) =>
            event.level != AppLogLevel.warning &&
            event.level != AppLogLevel.error,
      );
      if (_events.length > maxDisabledEvents) {
        _events.removeRange(0, _events.length - maxDisabledEvents);
      }
      await _deletePersistedLogs();
    } else {
      _schedulePersistence();
    }
    notifyListeners();
  }

  void add({
    required String level,
    required AppLogArea area,
    required String source,
    required String event,
    required String title,
    Object? data,
    List<String> tags = const <String>[],
    DateTime? time,
  }) {
    final normalizedLevel = AppLogLevel.parse(level);
    if (!_captureEnabled &&
        normalizedLevel != AppLogLevel.warning &&
        normalizedLevel != AppLogLevel.error) {
      return;
    }
    final now = time ?? DateTime.now();
    final entry = AppLogEvent(
      id: '${now.microsecondsSinceEpoch}-${_sequence++}',
      time: now,
      lastSeenAt: now,
      level: normalizedLevel,
      area: area,
      source: source.trim().isEmpty ? 'app' : source.trim(),
      event: event.trim().isEmpty ? 'log' : event.trim(),
      title: title.trim().isEmpty ? 'Log' : title.trim(),
      data: normalizeLogValue(data),
      tags: List.unmodifiable(tags),
    );
    final previous = _events.lastOrNull;
    if (previous != null &&
        now.difference(previous.lastSeenAt) <= duplicateWindow &&
        previous.deduplicationKey == entry.deduplicationKey) {
      _events[_events.length - 1] = previous.seenAgain(entry);
    } else {
      _events.add(entry);
    }
    _prune();
    notifyListeners();
    _schedulePersistence();
  }

  Future<void> clear() async {
    _persistTimer?.cancel();
    _persistenceGeneration++;
    _events.clear();
    notifyListeners();
    await _deletePersistedLogs();
    await _deleteLegacyHistory();
  }

  Future<void> flush() async {
    _persistTimer?.cancel();
    await _persist();
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(retention);
    _events.removeWhere((event) => event.lastSeenAt.isBefore(cutoff));
    final limit = _captureEnabled ? maxPersistentEvents : maxDisabledEvents;
    if (_events.length > limit) {
      _events.removeRange(0, _events.length - limit);
    }
  }

  void _schedulePersistence() {
    if (!_captureEnabled || _secureStorage == null) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(
      const Duration(milliseconds: 1500),
      () => unawaited(_persist()),
    );
  }

  Future<void> _persist() async {
    if (!_captureEnabled || _secureStorage == null) return;
    _persistPending = true;
    final running = _persistFuture;
    if (running != null) return running;
    final future = _drainPersistence();
    _persistFuture = future;
    try {
      await future;
    } finally {
      if (identical(_persistFuture, future)) _persistFuture = null;
    }
  }

  Future<void> _drainPersistence() async {
    try {
      while (_persistPending && _captureEnabled) {
        _persistPending = false;
        _prune();
        final generation = _persistenceGeneration;
        final serializable = _events
            .map((event) => event.toJson())
            .toList(growable: false);
        final key = await _loadOrCreateKey();
        final encrypted = await Isolate.run(
          () => _encodeEncryptedSnapshot(serializable, key, maxPersistentBytes),
        );
        if (!_captureEnabled || generation != _persistenceGeneration) {
          continue;
        }
        final file = await _logFile();
        await file.parent.create(recursive: true);
        await file.writeAsString(encrypted, flush: true);
        if (!_captureEnabled || generation != _persistenceGeneration) {
          if (await file.exists()) await file.delete();
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to persist encrypted logs: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadPersistedLogs() async {
    try {
      final file = await _logFile();
      if (!await file.exists()) return;
      final payload = await file.readAsString();
      final key = await _loadOrCreateKey();
      final decoded = await Isolate.run(() => _decryptSnapshot(payload, key));
      _events
        ..clear()
        ..addAll(decoded.map(AppLogEvent.fromJson).whereType<AppLogEvent>());
    } catch (error, stackTrace) {
      debugPrint('Failed to load encrypted logs: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _deletePersistedLogs();
    }
  }

  Future<Uint8List> _loadOrCreateKey() async {
    final storage = _secureStorage!;
    final saved = await storage.read(_encryptionKeyName);
    if (saved != null && saved.isNotEmpty) return base64Decode(saved);
    final key = _randomBytes(32);
    await storage.write(_encryptionKeyName, base64Encode(key));
    return key;
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Future<File> _logFile() async {
    final directory = await _supportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}logs'
      '${Platform.pathSeparator}events_v2.enc',
    );
  }

  Future<void> _deletePersistedLogs() async {
    if (_secureStorage == null) return;
    final file = await _logFile();
    if (await file.exists()) await file.delete();
  }

  Future<void> _deleteLegacyHistory() async {
    if (_secureStorage == null) return;
    final directory = await _supportDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}logs'
      '${Platform.pathSeparator}history_v1.json',
    );
    if (await file.exists()) await file.delete();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }
}

String _encodeEncryptedSnapshot(
  List<Map<String, dynamic>> events,
  Uint8List key,
  int maxEncryptedBytes,
) {
  final maxClearBytes = ((maxEncryptedBytes - 128) * 3) ~/ 4;
  final encodedEvents = events.map(jsonEncode).toList(growable: false);
  final selected = <String>[];
  var selectedBytes = 2;
  for (var index = encodedEvents.length - 1; index >= 0; index--) {
    final encoded = encodedEvents[index];
    final eventBytes = utf8.encode(encoded).length;
    final separatorBytes = selected.isEmpty ? 0 : 1;
    if (selectedBytes + separatorBytes + eventBytes > maxClearBytes) {
      if (selected.isEmpty) continue;
      break;
    }
    selected.add(encoded);
    selectedBytes += separatorBytes + eventBytes;
  }
  final clearBytes = Uint8List.fromList(
    utf8.encode('[${selected.reversed.join(',')}]'),
  );
  final nonce = _secureRandomBytes(12);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
  final encrypted = cipher.process(clearBytes);
  return jsonEncode(<String, String>{
    'nonce': base64Encode(nonce),
    'data': base64Encode(encrypted),
  });
}

List<dynamic> _decryptSnapshot(String payload, Uint8List key) {
  final envelope = Map<String, dynamic>.from(jsonDecode(payload) as Map);
  final nonce = base64Decode(envelope['nonce'] as String);
  final encrypted = base64Decode(envelope['data'] as String);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
  final clearBytes = cipher.process(encrypted);
  return jsonDecode(utf8.decode(clearBytes)) as List<dynamic>;
}

Uint8List _secureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}
