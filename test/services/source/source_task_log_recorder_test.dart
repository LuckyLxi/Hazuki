import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/logging/app_log_store.dart';
import 'package:hazuki/services/source/debug/source_task_log_recorder.dart';
import 'package:hazuki/services/source/runtime/source_task_registry.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

void main() {
  test(
    'capture redacts keywords and credentials while preserving identifiers and script frames',
    () async {
      final store = AppLogStore();
      addTearDown(store.dispose);
      await store.setCaptureEnabled(true);
      final registry = SourceTaskRegistry();
      final recorder = SourceTaskLogRecorder(store);
      const keyword = 'private "漫画"';
      final encoded = jsonEncode(keyword);
      final error = JSError(
        '$keyword ${Uri.encodeComponent(keyword)} ${encoded.substring(1, encoded.length - 1)} token=credential',
        'at search (source_search.js:12:3)',
      );
      await expectLater(
        registry.run<void>(
          pluginId: 'plugin',
          method: 'search.load',
          observe: (task, event, disposition, error, stack) => recorder.record(
            task,
            event,
            disposition,
            error,
            stack,
            sensitiveValues: [keyword],
          ),
          operation: (_) => throw error,
        ),
        throwsA(same(error)),
      );
      expect(store.events.map((event) => event.event), [
        'source_task_failed',
        'source_task_resources_settled',
      ]);
      final data =
          store.events
                  .singleWhere((event) => event.event == 'source_task_failed')
                  .data
              as Map;
      expect(data['error'], '[hidden] [hidden] [hidden] token=[hidden]');
      expect(data['scriptStack'], contains('source_search.js:12:3'));
      expect(data['taskId'], (store.events.first.data as Map)['taskId']);
      final settled = store.events.last.data as Map;
      expect(settled['settledAt'], isNotNull);
      expect(settled['taskId'], data['taskId']);
      expect(settled['sharedResourceCount'], 0);
      final exported = jsonEncode(
        store.events.map((event) => event.toJson()).toList(),
      );
      expect(exported, isNot(contains('credential')));
      expect(exported, isNot(contains('private')));
      expect(exported, isNot(contains('漫画')));
    },
  );

  test(
    'short search text does not redact task identity and capture switch is reused',
    () async {
      final store = AppLogStore();
      addTearDown(store.dispose);
      final registry = SourceTaskRegistry();
      final recorder = SourceTaskLogRecorder(store);
      Future<void> run() => registry.run<void>(
        pluginId: 'a-plugin',
        method: 'search.load',
        observe: (task, event, disposition, error, stack) => recorder.record(
          task,
          event,
          disposition,
          error,
          stack,
          sensitiveValues: ['a'],
        ),
        operation: (_) {},
      );
      await run();
      expect(store.events, isEmpty);
      await store.setCaptureEnabled(true);
      await run();
      expect(store.events, hasLength(1));
      expect((store.events.last.data as Map)['pluginId'], 'a-plugin');
      expect((store.events.last.data as Map)['state'], 'succeeded');
      await store.setCaptureEnabled(false);
      await run();
      expect(store.events, isEmpty);
    },
  );
}
