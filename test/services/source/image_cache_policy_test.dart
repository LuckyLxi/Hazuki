import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/common/source_prefs_keys.dart';
import 'package:hazuki/services/source/image/image_cache_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'uses safe defaults and skips maintenance without preferences',
    () async {
      var cleanCalls = 0;
      var trimCalls = 0;
      final policy = ImageCachePolicy(
        getPreferences: () => null,
        cleanByAge: (_) async {
          cleanCalls++;
        },
        trimToOverflow: ({required limitBytes, required targetRatio}) async {
          trimCalls++;
          return false;
        },
      );

      expect(policy.maxBytes, SourcePrefsKeys.defaultCacheMaxBytes);
      expect(policy.autoCleanMode, SourcePrefsKeys.defaultAutoCleanMode);
      await policy.setMaxBytes(1);
      await policy.setAutoCleanMode('seven_days');
      await policy.enforce();
      expect(cleanCalls, 0);
      expect(trimCalls, 0);
    },
  );

  test('normalizes settings and enforces the resulting policy', () async {
    SharedPreferences.setMockInitialValues({
      SourcePrefsKeys.cacheMaxBytes: 1,
      SourcePrefsKeys.cacheAutoCleanMode: 'invalid',
    });
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime(2026, 8, 17, 12);
    var cleanCalls = 0;
    final trimArguments = <(int, double)>[];
    final policy = ImageCachePolicy(
      getPreferences: () => preferences,
      cleanByAge: (_) async {
        cleanCalls++;
      },
      trimToOverflow: ({required limitBytes, required targetRatio}) async {
        trimArguments.add((limitBytes, targetRatio));
        return true;
      },
      now: () => now,
    );

    expect(policy.maxBytes, SourcePrefsKeys.defaultCacheMaxBytes);
    expect(policy.autoCleanMode, SourcePrefsKeys.defaultAutoCleanMode);

    await policy.setMaxBytes(2);
    expect(
      preferences.getInt(SourcePrefsKeys.cacheMaxBytes),
      SourcePrefsKeys.defaultCacheMaxBytes,
    );
    expect(trimArguments.single, (
      SourcePrefsKeys.defaultCacheMaxBytes,
      SourcePrefsKeys.cacheOverflowTrimTargetRatio,
    ));
    expect(
      preferences.getInt(SourcePrefsKeys.cacheLastAutoCleanAt),
      now.millisecondsSinceEpoch,
    );

    await policy.setAutoCleanMode('seven_days');
    expect(policy.autoCleanMode, 'seven_days');
    expect(cleanCalls, 1);
    expect(trimArguments, hasLength(2));

    await policy.setAutoCleanMode('unsupported');
    expect(policy.autoCleanMode, 'size_overflow');
  });

  test('runs age cleanup only when seven days have elapsed', () async {
    final now = DateTime(2026, 8, 17, 12);
    SharedPreferences.setMockInitialValues({
      SourcePrefsKeys.cacheAutoCleanMode: 'seven_days',
      SourcePrefsKeys.cacheLastAutoCleanAt: now
          .subtract(const Duration(days: 6))
          .millisecondsSinceEpoch,
    });
    final preferences = await SharedPreferences.getInstance();
    final cleanedDurations = <Duration>[];
    var trimCalls = 0;
    final policy = ImageCachePolicy(
      getPreferences: () => preferences,
      cleanByAge: (duration) async {
        cleanedDurations.add(duration);
      },
      trimToOverflow: ({required limitBytes, required targetRatio}) async {
        trimCalls++;
        return false;
      },
      now: () => now,
    );

    await policy.enforce();
    expect(cleanedDurations, isEmpty);
    expect(trimCalls, 1);

    await preferences.setInt(
      SourcePrefsKeys.cacheLastAutoCleanAt,
      now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
    );
    await policy.enforce();
    expect(cleanedDurations, [const Duration(days: 1)]);
    expect(trimCalls, 2);
    expect(
      preferences.getInt(SourcePrefsKeys.cacheLastAutoCleanAt),
      now.millisecondsSinceEpoch,
    );
  });

  test('coalesces non-forced maintenance while work is in flight', () async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    final firstTrim = Completer<bool>();
    var trimCalls = 0;
    final policy = ImageCachePolicy(
      getPreferences: () => preferences,
      cleanByAge: (_) async {},
      trimToOverflow: ({required limitBytes, required targetRatio}) {
        trimCalls++;
        return trimCalls == 1 ? firstTrim.future : Future.value(false);
      },
    );

    final first = policy.enforce();
    final second = policy.enforce();
    expect(trimCalls, 1);

    firstTrim.complete(false);
    await Future.wait([first, second]);
    await policy.enforce();
    expect(trimCalls, 2);
  });
}
