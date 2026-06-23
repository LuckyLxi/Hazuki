import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('services do not depend on feature implementations', () {
    final violations = <String>[];
    for (final file in _dartFiles(Directory('lib/services'))) {
      final content = file.readAsStringSync();
      final hasFeatureImport = content
          .split('\n')
          .any(
            (line) =>
                line.trimLeft().startsWith('import ') &&
                line.contains('features/'),
          );
      if (hasFeatureImport) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty, reason: 'service -> feature: $violations');
  });

  test('feature package imports do not form cycles', () {
    final root = Directory('lib/features');
    final graph = <String, Set<String>>{};
    final importPattern = RegExp(r'package:hazuki/features/([^/]+)/');

    for (final file in _dartFiles(root)) {
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
}

Iterable<File> _dartFiles(Directory directory) sync* {
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}
