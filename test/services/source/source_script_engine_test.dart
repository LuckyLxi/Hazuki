import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';

void main() {
  SourceScriptEngine createEngine({int timeout = 5000}) {
    final engine = SourceScriptEngine(timeout: timeout);
    addTearDown(engine.close);
    return engine;
  }

  test('preserves native values and synchronous host calls', () {
    final engine = createEngine();
    engine.setMessageHandler(
      (message) => {
        'text': message['text'],
        'bytes': Uint8List.fromList([0, 128, 255]),
        'enabled': true,
      },
    );
    expect(engine.evaluate('null'), isNull);
    expect(engine.evaluate('undefined'), isNull);
    expect(engine.evaluate('sendMessage({text: "漫画"})'), {
      'text': '漫画',
      'bytes': [0, 128, 255],
      'enabled': true,
    });
    expect(engine.evaluate('sendMessage({}).bytes.byteLength'), 3);
    expect(
      engine.invoke('(bytes) => new Uint8Array(bytes).buffer', [
        Uint8List.fromList([0, 128, 255]),
      ]),
      [0, 128, 255],
    );
  });

  for (final text in ['a', '漫画']) {
    test('preserves concatenated long strings containing $text', () async {
      final engine = createEngine();
      engine.setGlobal('text', text);
      final expected = '${text * 9000}${'b' * 9000}';
      const expression = 'text.repeat(9000) + "b".repeat(9000)';

      final evaluated = engine.evaluate(expression);
      expect(evaluated, isA<String>());
      expect(evaluated, expected);
      expect(engine.invoke('() => $expression', []), expected);
      expect(await engine.evaluate('Promise.resolve($expression)'), expected);

      dynamic body;
      engine.setMessageHandler((message) {
        body = message['body'];
        return body;
      });
      expect(engine.evaluate('sendMessage({body: $expression})'), expected);
      expect(body, expected);

      engine.setMessageHandler((message) async => message['body']);
      expect(
        await engine.evaluate('sendMessage({body: $expression})'),
        expected,
      );
    });
  }

  test('propagates script and host errors with the script name', () {
    final engine = createEngine();
    expect(
      () =>
          engine.evaluate('throw new Error("script failed")', name: 'main.js'),
      throwsA(predicate((error) => error.toString().contains('main.js'))),
    );
    engine.setMessageHandler((_) => throw StateError('host failed'));
    expect(
      engine.evaluate('try { sendMessage({}); } catch (e) { e.message; }'),
      contains('host failed'),
    );
  });

  test(
    'drives nested promises and delayed host futures without polling',
    () async {
      final engine = createEngine();
      engine.setMessageHandler((message) async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return message['value'];
      });
      expect(
        await engine.evaluate('''
(async () => {
  const first = await sendMessage({value: 20});
  const second = await Promise.resolve().then(() => sendMessage({value: 22}));
  return {answer: first + second};
})()
'''),
        {'answer': 42},
      );
      engine.setMessageHandler((_) => Future.error(StateError('async failed')));
      await expectLater(
        engine.evaluate('sendMessage({})'),
        throwsA(
          predicate((error) => error.toString().contains('async failed')),
        ),
      );
    },
  );

  for (final fail in [false, true]) {
    test('can close while a host Future is pending (failure: $fail)', () async {
      final engine = createEngine();
      final response = Completer<int>();
      engine.setMessageHandler((_) => response.future);
      final pending = engine.evaluate('sendMessage({})');
      final assertion = fail
          ? expectLater(pending, throwsA(anything))
          : expectLater(pending, completion(42));
      engine.close();
      engine.close();
      expect(() => engine.evaluate('1'), throwsStateError);
      if (fail) {
        response.completeError(StateError('cancelled'));
      } else {
        response.complete(42);
      }
      await assertion;
      // Native Promise callbacks and deferred disposal must finish without
      // accessing references freed by close().
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
  }

  test(
    'keeps runtime globals isolated when another runtime is closed',
    () async {
      final first = createEngine();
      final second = createEngine();
      first.setGlobal('value', 'first');
      second.setGlobal('value', 'second');
      first.close();
      expect(await second.evaluate('Promise.resolve(value)'), 'second');
    },
  );

  test(
    'interrupts runaway evaluation, function calls and promise jobs',
    () async {
      final engine = createEngine(timeout: 20);
      final interrupted = predicate(
        (error) => error.toString().contains('interrupted'),
      );
      expect(() => engine.evaluate('while (true) {}'), throwsA(interrupted));
      expect(engine.evaluate('1 + 1'), 2);
      expect(
        () => engine.invoke('() => { while (true) {} }', []),
        throwsA(interrupted),
      );
      await expectLater(
        engine.evaluate('Promise.resolve().then(() => { while (true) {} })'),
        throwsA(interrupted),
      );
      await expectLater(
        engine.invoke(
          '() => Promise.resolve().then(() => { while (true) {} })',
          [],
        ),
        throwsA(interrupted),
      );
      expect(await engine.evaluate('Promise.resolve(42)'), 42);
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );
}
