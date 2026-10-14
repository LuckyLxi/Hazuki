import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('favorite workflows depend on narrow state and injected callbacks', () {
    for (final name in [
      'favorite_folder_coordinator.dart',
      'favorite_sort_flow.dart',
    ]) {
      final content = File(
        'lib/features/favorite/support/$name',
      ).readAsStringSync();
      for (final forbidden in [
        'favorite_page_controller.dart',
        'FavoritePageController',
        'favorite_page_state.dart',
        'FavoritePageData',
        '/view/',
        'BuildContext',
        'package:flutter/material.dart',
        'favorite_list_loader.dart',
      ]) {
        expect(content, isNot(contains(forbidden)), reason: name);
      }
    }
    for (final name in [
      'favorite_folder_state.dart',
      'favorite_sort_state.dart',
    ]) {
      final content = File(
        'lib/features/favorite/state/$name',
      ).readAsStringSync();
      expect(
        content,
        isNot(contains('favorite_page_state.dart')),
        reason: name,
      );
      expect(content, isNot(contains('/support/')), reason: name);
    }
  });

  test('reader controllers use narrow state contracts', () {
    for (final name in [
      'reader_settings_controller.dart',
      'reader_zoom_controller.dart',
      'reader_image_pipeline_controller.dart',
    ]) {
      final content = File(
        'lib/features/reader/support/$name',
      ).readAsStringSync();
      expect(
        content,
        isNot(contains('reader_runtime_state.dart')),
        reason: name,
      );
      expect(content, isNot(contains('ReaderRuntimeState')), reason: name);
    }
    for (final name in [
      'reader_settings_state.dart',
      'reader_zoom_state.dart',
      'reader_image_content_state.dart',
    ]) {
      final content = File(
        'lib/features/reader/state/$name',
      ).readAsStringSync();
      expect(
        content,
        isNot(contains('reader_runtime_state.dart')),
        reason: name,
      );
      expect(content, isNot(contains('/support/')), reason: name);
    }
  });

  test('reader settings receives navigation and zoom through callbacks', () {
    final content = File(
      'lib/features/reader/support/reader_settings_controller.dart',
    ).readAsStringSync();
    expect(content, isNot(contains('reader_navigation_controller.dart')));
    expect(content, isNot(contains('reader_zoom_controller.dart')));
    expect(content, isNot(contains('ReaderNavigationController')));
    expect(content, isNot(contains('ReaderZoomController')));
  });

  test('cloud sync orchestration does not depend on business services', () {
    final service = File(
      'lib/services/cloud_sync_service.dart',
    ).readAsStringSync();
    for (final dependency in [
      'local_favorites_contracts.dart',
      'local_favorites_service.dart',
      'comment_filter_service.dart',
      'download_groups_service.dart',
    ]) {
      expect(service, isNot(contains(dependency)));
    }
  });

  test('comment filter sync uses the data owner contract', () {
    final participant = File(
      'lib/services/cloud_sync/cloud_sync_comment_filter_participant.dart',
    ).readAsStringSync();
    expect(participant, isNot(contains('package:shared_preferences/')));
    expect(participant, isNot(contains('SharedPreferences')));
    expect(participant, isNot(contains('comment_filter_service.dart')));
    final contract = File(
      'lib/services/comment_filter/comment_filter_sync_store.dart',
    ).readAsStringSync();
    expect(contract, isNot(contains('package:shared_preferences/')));
    expect(contract, isNot(contains('cloud_sync/')));
  });

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
