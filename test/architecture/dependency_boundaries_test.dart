import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('feature package imports do not form cycles', () {
    final root = Directory('lib/features');
    final graph = <String, Set<String>>{};
    final importPattern = RegExp(r'package:hazuki/features/([^/]+)/');

    for (final file in _dartFilesUnder(root.path)) {
      final relative = file.path.substring(root.path.length + 1);
      final from = relative.split(Platform.pathSeparator).first;
      final targets = graph.putIfAbsent(from, () => <String>{});
      for (final match in importPattern.allMatches(file.readAsStringSync())) {
        final to = match.group(1)!;
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
        if (file.path
            .replaceAll('\\', '/')
            .endsWith('lib/app/service_locator.dart')) {
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

  test('service locator obtains source gateways from the gateway set', () {
    final content = File('lib/app/service_locator.dart').readAsStringSync();
    expect(content.contains('HazukiSource'), isFalse);
    expect(content.contains('.gateways.'), isTrue);
  });

  test('migrated source capabilities use explicit runtime dependencies', () {
    const paths = [
      'lib/services/source/explore_capability.dart',
      'lib/services/source/category/source_category_capability.dart',
      'lib/services/source/comic/source_comic_details_cache.dart',
      'lib/services/source/comic/comic_details_capability.dart',
      'lib/services/source/account/source_relogin_coordinator.dart',
      'lib/services/source/account/source_daily_check_in_capability.dart',
      'lib/services/source/favorites/source_favorites_capability.dart',
      'lib/services/source/image/source_image_preparation_capability.dart',
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
}

Iterable<File> _dartFilesUnder(String path) sync* {
  final directory = Directory(path);
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}
