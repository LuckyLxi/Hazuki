import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'update dialogs keep reminder persistence and dates behind collaborators',
    () {
      final presenter = File(
        'lib/shared/software_update/software_update_dialog_presenter.dart',
      ).readAsStringSync();
      expect(presenter, isNot(contains('package:shared_preferences/')));
      expect(presenter, isNot(contains('dart:convert')));
      expect(presenter, isNot(contains('DateTime.now')));
      final policy = File(
        'lib/services/software_update/software_update_reminder_policy.dart',
      ).readAsStringSync();
      expect(policy, isNot(contains('package:flutter/')));
      expect(policy, isNot(contains('package:shared_preferences/')));
      expect(policy, isNot(contains('software_update_dialog_presenter.dart')));
    },
  );

  test('reader image collaborators do not depend on reader orchestration', () {
    for (final name in [
      'reader_image_loader.dart',
      'reader_image_prefetch_scheduler.dart',
    ]) {
      final content = File(
        'lib/features/reader/support/$name',
      ).readAsStringSync();
      expect(content, isNot(contains('reader_runtime_state.dart')));
      expect(content, isNot(contains('reader_image_pipeline_controller.dart')));
      expect(content, isNot(contains('BuildContext')));
    }
    final controller = File(
      'lib/features/reader/support/reader_image_pipeline_controller.dart',
    ).readAsStringSync();
    expect(controller, isNot(contains('dart:io')));
    expect(controller, isNot(contains('instantiateImageCodec')));
    expect(controller, isNot(contains('decodeWaiters')));
  });

  test('download group storage and sync stay behind focused collaborators', () {
    final service = File(
      'lib/services/download_groups_service.dart',
    ).readAsStringSync();
    expect(service, isNot(contains('package:drift/')));
    expect(service, isNot(contains('dart:convert')));
    for (final file in Directory(
      'lib/services/download_groups',
    ).listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final content = file.readAsStringSync();
      expect(
        content,
        isNot(contains('download_groups_service.dart')),
        reason: file.path,
      );
      if (!file.path.endsWith('download_groups_persistence.dart')) {
        expect(content, isNot(contains('package:drift/')), reason: file.path);
        expect(
          content,
          isNot(contains('hazuki_database.dart')),
          reason: file.path,
        );
      }
    }
  });

  test('download feature depends on contracts and models', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib/features/downloads',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final content = file.readAsStringSync();
      if (content.contains('manga_download_service.dart') ||
          content.contains('download_groups_service.dart')) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test(
    'reader and details do not import the download service implementation',
    () {
      final violations = <String>[];
      for (final feature in ['reader', 'comic_detail']) {
        for (final file in Directory(
          'lib/features/$feature',
        ).listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          if (file.readAsStringSync().contains('manga_download_service.dart')) {
            violations.add(file.path);
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test(
    'recommendation collaborators do not depend on their service facade',
    () {
      for (final file in Directory(
        'lib/services/discover_daily_recommendation',
      ).listSync().whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        expect(
          file.readAsStringSync(),
          isNot(contains('DiscoverDailyRecommendationService')),
          reason: file.path,
        );
        expect(
          file.readAsStringSync(),
          isNot(contains('discover_daily_recommendation_service.dart')),
          reason: file.path,
        );
      }
    },
  );
}
