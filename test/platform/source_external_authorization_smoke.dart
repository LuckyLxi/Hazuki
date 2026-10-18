// Run after building test/platform/fixtures/external_authorization into
// build/mock-external-auth, with flutter run -d windows -t this file.
// Uses only synthetic results. Registry entries are scoped to this test process.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hazuki/services/source/account/source_external_authorization.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Authorization integration test')),
      ),
    ),
  );
  final report = <String, bool>{};
  final scheme = 'hazuki-auth-mock-$pid';
  final key = 'HKCU\\Software\\Classes\\$scheme';
  final fixture = File(
    'build/mock-external-auth/Debug/hazuki_mock_authorization.exe',
  ).absolute;
  final command = '"${fixture.path}" "%1"';
  final broker = SourceExternalAuthorizationBroker.instance;
  final active = <(String, SourceLoginCancellation)>[];
  try {
    if (!await fixture.exists()) throw StateError('mock_app_missing');
    for (final args in [
      [
        'add',
        key,
        '/ve',
        '/t',
        'REG_SZ',
        '/d',
        'URL:Hazuki test provider',
        '/f',
      ],
      ['add', key, '/v', 'URL Protocol', '/t', 'REG_SZ', '/d', '', '/f'],
      [
        'add',
        '$key\\shell\\open\\command',
        '/ve',
        '/t',
        'REG_SZ',
        '/d',
        command,
        '/f',
      ],
    ]) {
      if ((await Process.run('reg.exe', args)).exitCode != 0) {
        throw StateError('mock_registration_failed');
      }
    }
    report['mockRegistered'] = true;
    final results = <Future<Map<String, Object>>>[];
    final callbacks = <String>[];
    for (var i = 0; i < 2; i++) {
      final token = SourceLoginCancellation();
      final created = await broker.prepare({
        'allowedSchemes': [scheme],
      }, token);
      final id = created['id'] as String;
      report['preparedSession'] = true;
      final callback = created['callbackUrl'] as String;
      callbacks.add(callback);
      active.add((id, token));
      final session = broker.require(id, token);
      final wrong = await Process.run(Platform.resolvedExecutable, [
        '$callback-wrong?code=synthetic',
      ]);
      if (wrong.exitCode != 0 || !session.active) {
        throw StateError('bad_callback');
      }
      report['wrongCallbackDiscarded'] = true;
      results.add(
        session.launch(
          '$scheme://authorize?callback=${Uri.encodeComponent(callback)}',
        ),
      );
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    for (var i = 0; i < active.length; i++) {
      final session = broker.require(active[i].$1, active[i].$2);
      if (session.active) {
        report['providerCallbackMissing'] = false;
        await Process.run(Platform.resolvedExecutable, [
          '${callbacks[i]}?code=synthetic&state=mock-state',
        ]);
      }
    }
    final values = await Future.wait(
      results,
    ).timeout(const Duration(seconds: 20));
    report['multipleSessionsAndCrossProcessCallback'] =
        values.every((v) => v['status'] == 'completed') &&
        values[0]['url'] == '${callbacks[0]}?code=synthetic&state=mock-state' &&
        values[1]['url'] == '${callbacks[1]}?code=synthetic&state=mock-state';
    for (final session in active) {
      await broker.close(session.$1, session.$2);
    }
    for (final callback in callbacks) {
      if ((await Process.run(Platform.resolvedExecutable, [
            '$callback?code=duplicate',
          ])).exitCode !=
          0) {
        throw StateError('duplicate_failed');
      }
    }
    report['duplicateAndUnownedCallbacksDiscarded'] = true;
    final token = SourceLoginCancellation();
    final pending = await broker.prepare({
      'allowedSchemes': [scheme],
    }, token);
    active.add((pending['id'] as String, token));
    token.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    report['cancelledCallbackDiscarded'] =
        (await Process.run(Platform.resolvedExecutable, [
          '${pending['callbackUrl']}?code=late',
        ])).exitCode ==
        0;
    final missingToken = SourceLoginCancellation();
    final missing = await broker.prepare({
      'allowedSchemes': ['hazuki-absent-$pid'],
    }, missingToken);
    active.add((missing['id'] as String, missingToken));
    try {
      await broker
          .require(missing['id'] as String, missingToken)
          .launch('hazuki-absent-$pid://login');
      report['missingAppReturnsSafeError'] = false;
    } catch (error) {
      report['missingAppReturnsSafeError'] =
          error is StateError &&
          error.message == 'login_external_app_unavailable';
    }
    report['passed'] = report.values.every((v) => v);
  } catch (error) {
    if (error is StateError) report[error.message] = false;
    report['passed'] = false;
  } finally {
    for (final session in active) {
      await broker.close(session.$1, session.$2);
    }
    // Delete only this run's explicitly named, owned test protocol.
    final current = await Process.run('reg.exe', [
      'query',
      '$key\\shell\\open\\command',
      '/ve',
    ]);
    if (current.exitCode == 0 && current.stdout.toString().contains(command)) {
      await Process.run('reg.exe', ['delete', key, '/f']);
    }
    await File(
      'build/external-auth-native-smoke.json',
    ).writeAsString(jsonEncode(report));
  }
  exit(report['passed'] == true ? 0 : 1);
}
