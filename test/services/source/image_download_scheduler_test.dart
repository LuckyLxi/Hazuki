import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/image/image_download_scheduler.dart';

void main() {
  test('starts no more than the configured number of tasks', () async {
    final scheduler = ImageDownloadScheduler(maxConcurrent: 2);
    final started = <String>[];
    final first = Completer<String>();
    final second = Completer<String>();
    final third = Completer<String>();

    final futures = [
      scheduler.schedule(
        'first',
        priority: false,
        task: () {
          started.add('first');
          return first.future;
        },
      ),
      scheduler.schedule(
        'second',
        priority: false,
        task: () {
          started.add('second');
          return second.future;
        },
      ),
      scheduler.schedule(
        'third',
        priority: false,
        task: () {
          started.add('third');
          return third.future;
        },
      ),
    ];

    await _flushAsyncWork();
    expect(started, ['first', 'second']);

    first.complete('first');
    await _flushAsyncWork();
    expect(started, ['first', 'second', 'third']);

    second.complete('second');
    third.complete('third');
    expect(await Future.wait(futures), ['first', 'second', 'third']);
  });

  test('starts newly queued priority work before normal work', () async {
    final scheduler = ImageDownloadScheduler(maxConcurrent: 1);
    final started = <String>[];
    final active = Completer<void>();
    final normal = Completer<void>();
    final priority = Completer<void>();

    final futures = [
      scheduler.schedule(
        'active',
        priority: false,
        task: () {
          started.add('active');
          return active.future;
        },
      ),
      scheduler.schedule(
        'normal',
        priority: false,
        task: () {
          started.add('normal');
          return normal.future;
        },
      ),
      scheduler.schedule(
        'priority',
        priority: true,
        task: () {
          started.add('priority');
          return priority.future;
        },
      ),
    ];

    await _flushAsyncWork();
    active.complete();
    await _flushAsyncWork();
    expect(started, ['active', 'priority']);

    priority.complete();
    await _flushAsyncWork();
    expect(started, ['active', 'priority', 'normal']);

    normal.complete();
    await Future.wait(futures);
  });

  test('promotes matching pending work without duplicating it', () async {
    final scheduler = ImageDownloadScheduler(maxConcurrent: 1);
    final started = <String>[];
    final active = Completer<void>();
    final second = Completer<void>();
    final third = Completer<void>();

    final futures = [
      scheduler.schedule(
        'active',
        priority: false,
        task: () {
          started.add('active');
          return active.future;
        },
      ),
      scheduler.schedule(
        'second',
        priority: false,
        task: () {
          started.add('second');
          return second.future;
        },
      ),
      scheduler.schedule(
        'third',
        priority: false,
        task: () {
          started.add('third');
          return third.future;
        },
      ),
    ];

    await _flushAsyncWork();
    scheduler.promote('third');
    scheduler.promote('missing');
    active.complete();
    await _flushAsyncWork();
    expect(started, ['active', 'third']);

    third.complete();
    await _flushAsyncWork();
    second.complete();
    await Future.wait(futures);
    expect(started, ['active', 'third', 'second']);
  });

  test('releases a slot when a task fails', () async {
    final scheduler = ImageDownloadScheduler(maxConcurrent: 1);
    final started = <String>[];
    final failed = Completer<void>();
    final failure = scheduler.schedule(
      'failed',
      priority: false,
      task: () {
        started.add('failed');
        return failed.future;
      },
    );
    final failureExpectation = expectLater(failure, throwsStateError);
    final next = scheduler.schedule(
      'next',
      priority: false,
      task: () async {
        started.add('next');
        return 'done';
      },
    );

    await _flushAsyncWork();
    failed.completeError(StateError('failed'));

    await failureExpectation;
    expect(await next, 'done');
    expect(started, ['failed', 'next']);
  });
}

Future<void> _flushAsyncWork() => Future<void>.delayed(Duration.zero);
