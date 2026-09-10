import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('features use shared contracts instead of app controllers', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/features')) {
      for (final line in file.readAsLinesSync()) {
        final directive = line.trimLeft();
        if (!directive.startsWith('import ') &&
            !directive.startsWith('export ')) {
          continue;
        }
        if (!line.replaceAll('\\', '/').contains('/app/')) continue;
        violations.add('${file.path}: $line');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('services do not depend on feature implementations', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services')) {
      final content = file.readAsStringSync();
      final hasFeatureImport = content
          .split('\n')
          .any(
            (line) =>
                line.trimLeft().startsWith('import ') &&
                line.contains('features/'),
          );
      if (hasFeatureImport) violations.add(file.path);
    }
    expect(violations, isEmpty, reason: 'service -> feature: $violations');
  });

  test('services do not import the app layer', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services')) {
      for (final line in file.readAsLinesSync()) {
        if (!line.trimLeft().startsWith('import ')) continue;
        final normalized = line.replaceAll('\\', '/');
        if (normalized.contains('/app/') ||
            normalized.contains("'../app/") ||
            normalized.contains("'../../app/")) {
          violations.add('${file.path}: $line');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('announcement feature consumers depend on contracts', () {
    final violations = <String>[];
    for (final directory in const ['lib/features', 'lib/app/home']) {
      for (final file in _dartFilesUnder(directory)) {
        for (final line in file.readAsLinesSync()) {
          if (!line.trimLeft().startsWith('import ')) continue;
          if (line.contains('services/announcement_service.dart') ||
              line.contains('announcements/announcement_service.dart') ||
              line.contains('announcements/announcement_remote_source.dart') ||
              line.contains('announcements/announcement_store.dart')) {
            violations.add('${file.path}: $line');
          }
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Announcement consumers must use contracts: $violations',
    );
  });

  test('announcements do not depend on software update implementations', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services/announcements')) {
      for (final line in file.readAsLinesSync()) {
        final directive = line.trimLeft();
        if ((directive.startsWith('import ') ||
                directive.startsWith('export ')) &&
            line.contains('software_update/')) {
          violations.add('${file.path}: $line');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('source gateways do not import runtime implementations', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services/source/gateways')) {
      for (final line in file.readAsLinesSync()) {
        if (line.contains('source_runtime_assembly.dart') ||
            line.contains('source_runtime_capability.dart')) {
          violations.add('${file.path}: $line');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('source runtime components do not import the source assembly', () {
    final violations = <String>[];
    for (final directory in const [
      'lib/services/source/runtime',
      'lib/services/source/http',
      'lib/services/source/image',
      'lib/services/source/debug',
    ]) {
      for (final file in _dartFilesUnder(directory)) {
        for (final line in file.readAsLinesSync()) {
          if (line.trimLeft().startsWith('import ') &&
              line.contains('source_runtime_assembly.dart')) {
            violations.add('${file.path}: $line');
          }
        }
      }
    }
    expect(
      File('lib/services/hazuki_source_service.dart').existsSync(),
      isFalse,
    );
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('source collaborators do not use service part libraries', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services/source')) {
      final content = file.readAsStringSync();
      if (RegExp(r'^part of ', multiLine: true).hasMatch(content)) {
        violations.add('${file.path}: part of');
      }
      final isAdapter = file.path.replaceAll('\\', '/').contains('/adapters/');
      final isAssembly = file.path
          .replaceAll('\\', '/')
          .endsWith('source_runtime_assembly.dart');
      if (!isAdapter &&
          !isAssembly &&
          content.contains('source_runtime_assembly.dart')) {
        violations.add('${file.path}: source assembly import');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('cloud sync participants do not use the global service locator', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services/cloud_sync')) {
      final content = file.readAsStringSync();
      if (content.contains('app/service_locator.dart') ||
          RegExp(r'\bsl<').hasMatch(content)) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty, reason: 'cloud sync locator use: $violations');
  });

  test('shared and widget modules do not use the global service locator', () {
    final violations = <String>[];
    for (final directory in const ['lib/shared', 'lib/widgets']) {
      for (final file in _dartFilesUnder(directory)) {
        final content = file.readAsStringSync();
        if (content.contains('app/service_locator.dart') ||
            RegExp(r'\bsl<').hasMatch(content)) {
          violations.add(file.path);
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('relative and package feature dependencies do not form cycles', () {
    final root = Directory('lib/features');
    final graph = <String, Set<String>>{};
    final featureRoot = root.absolute.uri.toString();

    for (final file in _dartFilesUnder(root.path)) {
      final relative = file.path.substring(root.path.length + 1);
      final from = relative.split(Platform.pathSeparator).first;
      final targets = graph.putIfAbsent(from, () => <String>{});
      for (final uri in _dependencyUris(
        file.readAsStringSync(),
        file.absolute.uri,
      )) {
        final target = uri.toString();
        if (!target.startsWith(featureRoot)) continue;
        final to = target.substring(featureRoot.length).split('/').first;
        if (to != from) targets.add(to);
      }
    }

    final visiting = <String>{};
    final visited = <String>{};
    final stack = <String>[];
    List<String>? cycle;

    bool visit(String node) {
      if (visiting.contains(node)) {
        final start = stack.indexOf(node);
        cycle = [...stack.sublist(start), node];
        return true;
      }
      if (visited.contains(node)) return false;
      visiting.add(node);
      stack.add(node);
      for (final next in graph[node] ?? const <String>{}) {
        if (visit(next)) return true;
      }
      stack.removeLast();
      visiting.remove(node);
      visited.add(node);
      return false;
    }

    for (final node in graph.keys) {
      if (visit(node)) break;
    }
    expect(cycle, isNull, reason: 'feature dependency cycle: $cycle');
  });

  test(
    'business features use injected builders for comments and favorites',
    () {
      final violations = <String>[];

      for (final file in _dartFilesUnder('lib/features/reader')) {
        final content = file.readAsStringSync();
        if (content.contains('features/comments/')) {
          violations.add('${file.path}: reader -> comments');
        }
      }

      for (final file in _dartFilesUnder('lib/features/comic_detail')) {
        final content = file.readAsStringSync();
        if (content.contains('features/comments/')) {
          violations.add('${file.path}: comic_detail -> comments');
        }
      }

      for (final file in _dartFilesUnder('lib/features/history')) {
        final content = file.readAsStringSync();
        if (content.contains('features/favorite/')) {
          violations.add('${file.path}: history -> favorite');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Reader/Comic Detail must receive comments builders; History must '
            'receive favorite callbacks: $violations',
      );
    },
  );

  test(
    'reader feature receives app services through injected dependencies',
    () {
      final violations = <String>[];
      for (final file in _dartFilesUnder('lib/features/reader')) {
        final content = file.readAsStringSync();
        if (content.contains('app/service_locator.dart') ||
            RegExp(r'\bsl<').hasMatch(content)) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Inject reader services from the app layer: $violations',
      );
    },
  );

  test('core business features receive app services through injection', () {
    final violations = <String>[];
    for (final feature in const [
      'comments',
      'comic_detail',
      'discover',
      'downloads',
      'favorite',
      'history',
      'search',
    ]) {
      for (final file in _dartFilesUnder('lib/features/$feature')) {
        final content = file.readAsStringSync();
        if (content.contains('app/service_locator.dart') ||
            RegExp(r'\bsl<').hasMatch(content)) {
          violations.add(file.path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Inject core business feature services: $violations',
    );
  });

  test('settings feature receives app services through injection', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/features/settings')) {
      final content = file.readAsStringSync();
      if (content.contains('app/service_locator.dart') ||
          RegExp(r'\bsl<').hasMatch(content)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Inject settings feature services: $violations',
    );
  });

  test('home feature receives sibling features through app entrypoints', () {
    final violations = <String>[];
    final featureImportPattern = RegExp(r'package:hazuki/features/([^/]+)/');

    for (final file in _dartFilesUnder('lib/features/home')) {
      final content = file.readAsStringSync();
      for (final match in featureImportPattern.allMatches(content)) {
        final feature = match.group(1)!;
        if (feature != 'home') {
          violations.add('${file.path}: features/$feature');
        }
      }
      if (content.contains('app/service_locator.dart') ||
          RegExp(r'\bsl<').hasMatch(content)) {
        violations.add('${file.path}: service locator');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Inject home feature entrypoints/services: $violations',
    );
  });

  test(
    'services do not resolve dependencies through the app service locator',
    () {
      final violations = _dartFilesUnder('lib/services')
          .where(
            (file) =>
                file.readAsStringSync().contains('app/service_locator.dart'),
          )
          .map((file) => file.path)
          .toList();

      expect(
        violations,
        isEmpty,
        reason: 'Inject service dependencies: $violations',
      );
    },
  );

  test('application and features do not depend on source implementations', () {
    final violations = <String>[];
    for (final directory in const ['lib/app', 'lib/features']) {
      for (final file in _dartFilesUnder(directory)) {
        final normalizedPath = file.path.replaceAll('\\', '/');
        if (normalizedPath.endsWith('lib/app/service_locator.dart') ||
            normalizedPath.endsWith(
              'lib/app/di/source_service_registrar.dart',
            )) {
          continue;
        }
        final content = file.readAsStringSync();
        if (content.contains(
              'services/source/runtime/source_runtime_assembly.dart',
            ) ||
            content.contains(
              'services/source/runtime/source_runtime_capability.dart',
            ) ||
            content.contains('sl<SourceRuntimeAssembly>') ||
            content.contains('.facade')) {
          violations.add(file.path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Depend on source gateway contracts: $violations',
    );
  });

  test('source gateways are backed by focused adapters', () {
    final forbidden =
        'HazukiSource'
        'Capabilities';
    final violations = <String>[];
    for (final root in const ['lib', 'test']) {
      for (final file in _dartFilesUnder(root)) {
        if (file.readAsStringSync().contains(forbidden)) {
          violations.add(file.path);
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Do not reintroduce the aggregate source adapter: $violations',
    );
  });

  test('source adapters do not depend on the runtime assembly', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/services/source/adapters')) {
      final content = file.readAsStringSync();
      if (content.contains('source_runtime_assembly.dart') ||
          RegExp(r'\bSourceRuntimeAssembly\b').hasMatch(content) ||
          RegExp(r'\bdynamic\s+source\b').hasMatch(content)) {
        violations.add(file.path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Adapters must consume explicit runtime collaborators: $violations',
    );
  });

  test('service locator depends on registrars instead of services', () {
    final file = File('lib/app/service_locator.dart');
    expect(
      _dependencyUris(
        file.readAsStringSync(),
        file.absolute.uri,
      ).where((uri) => uri.path.contains('/services/')),
      isEmpty,
    );
  });

  test('migrated source capabilities use explicit runtime dependencies', () {
    const paths = [
      'lib/services/source/explore_capability.dart',
      'lib/services/source/category/source_category_capability.dart',
      'lib/services/source/comic/source_comic_details_cache.dart',
      'lib/services/source/comic/source_comic_details_parser.dart',
      'lib/services/source/comic/comic_details_capability.dart',
      'lib/services/source/account/source_relogin_coordinator.dart',
      'lib/services/source/account/source_daily_check_in_capability.dart',
      'lib/services/source/account/source_login_operations.dart',
      'lib/services/source/account/source_login_script_factory.dart',
      'lib/services/source/account/source_login_side_data_operations.dart',
      'lib/services/source/account/picacg_login_profile_operations.dart',
      'lib/services/source/account/picacg_login_profile_parser.dart',
      'lib/services/source/account/picacg_profile_script_factory.dart',
      'lib/services/source/favorites/source_favorites_capability.dart',
      'lib/services/source/favorites/source_favorite_comics_loader.dart',
      'lib/services/source/favorites/source_favorites_policy.dart',
      'lib/services/source/favorites/source_favorites_response_parser.dart',
      'lib/services/source/favorites/source_favorite_folder_membership_probe.dart',
      'lib/services/source/favorites/source_favorites_script_factory.dart',
      'lib/services/source/image/source_image_preparation_capability.dart',
      'lib/services/source/image/image_download_scheduler.dart',
      'lib/services/source/image/image_disk_cache_store.dart',
      'lib/services/source/image/image_cache_policy.dart',
      'lib/services/source/image/source_image_network_downloader.dart',
      'lib/services/source/runtime/source_runtime_host.dart',
    ];
    final violations = <String>[];
    for (final path in paths) {
      final content = File(path).readAsStringSync();
      if (RegExp(r'^part of ', multiLine: true).hasMatch(content) ||
          content.contains('source_runtime_assembly.dart') ||
          content.contains('app/service_locator.dart')) {
        violations.add(path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Migrated source collaborators must have explicit dependencies: '
          '$violations',
    );
  });

  // Runtime, account, favorites, logging and cache behavior is covered by
  // test/services/source/*_test.dart and test/app/service_registration_test.dart.
  // Architecture tests constrain dependencies, not collaborator variable names.
  for (final rule in <String, List<String>>{
    'runtime/source_runtime_capability.dart': [
      'package:dio/',
      'package:flutter_qjs/',
      'package:flutter/services.dart',
    ],
    'account/account_session_capability.dart': ['dart:convert'],
    'account/source_login_operations.dart': ['dart:convert'],
    'account/picacg_login_profile_operations.dart': ['dart:convert'],
    'favorites/source_favorites_capability.dart': ['dart:convert'],
    'image/image_cache_capability.dart': [
      'dart:async',
      'dart:collection',
      'dart:convert',
      'package:crypto/',
      'package:path_provider/',
    ],
  }.entries) {
    test('${rule.key} keeps infrastructure behind collaborators', () {
      final file = File('lib/services/source/${rule.key}');
      final violations = _dependencyUris(
        file.readAsStringSync(),
        file.absolute.uri,
      ).where((uri) => rule.value.any(uri.toString().startsWith));
      expect(violations, isEmpty);
    });
  }

  test(
    'navigation depends on its state contract instead of implementations',
    () {
      final file = File(
        'lib/features/reader/support/reader_navigation_controller.dart',
      );
      final dependencies = _dependencyUris(
        file.readAsStringSync(),
        file.absolute.uri,
      );
      expect(
        dependencies.where(
          (uri) =>
              uri.path.endsWith('/reader_runtime_state.dart') ||
              uri.path.endsWith('/reader_image_pipeline_controller.dart') ||
              uri.path.contains('/services/'),
        ),
        isEmpty,
      );
    },
  );

  test('dependency resolution includes relative and package directives', () {
    final file = File('lib/features/reader/view/example.dart');
    final dependencies = _dependencyUris(
      "import '../../search/search.dart';\n"
      "export 'package:hazuki/features/search/search.dart';\n"
      "// import '../../ignored/ignored.dart';\n"
      "import 'dart:async';",
      file.absolute.uri,
    ).toList();
    expect(dependencies, [
      File('lib/features/search/search.dart').absolute.uri,
      File('lib/features/search/search.dart').absolute.uri,
      Uri.parse('dart:async'),
    ]);
  });
}

Iterable<File> _dartFilesUnder(String path) sync* {
  final directory = Directory(path);
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

Iterable<Uri> _dependencyUris(String source, Uri fileUri) sync* {
  final directives = RegExp(
    r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""",
    multiLine: true,
  );
  for (final match in directives.allMatches(source)) {
    final value = match.group(1)!;
    if (value.startsWith('package:hazuki/')) {
      yield Directory(
        'lib',
      ).absolute.uri.resolve(value.substring('package:hazuki/'.length));
    } else {
      yield fileUri.resolve(value);
    }
  }
}
