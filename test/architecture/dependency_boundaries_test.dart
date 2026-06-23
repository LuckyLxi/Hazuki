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

  test('features do not depend on the concrete source service or facade', () {
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib/features')) {
      final content = file.readAsStringSync();
      if (content.contains('services/hazuki_source_service.dart') ||
          content.contains('sl<HazukiSourceService>') ||
          content.contains('.facade')) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Depend on a source gateway: $violations',
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
}

Iterable<File> _dartFilesUnder(String path) sync* {
  final directory = Directory(path);
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}
