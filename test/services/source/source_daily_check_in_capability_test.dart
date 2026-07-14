import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_daily_check_in_capability.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  test('recognizes supported sources and normalizes daily check-in data', () {
    expect(SourceDailyCheckInCapability.supportsSource('jm'), isTrue);
    expect(SourceDailyCheckInCapability.supportsSource('picacg'), isTrue);
    expect(SourceDailyCheckInCapability.supportsSource('copy_manga'), isFalse);
    expect(
      SourceDailyCheckInCapability.dailyCheckInDateTag(
        DateTime(2026, 7, 14, 12),
      ),
      '2026-07-14',
    );
    expect(
      SourceDailyCheckInCapability.parseDailyCheckInMap(
        '{"daily_id":"record"}',
      ),
      {'daily_id': 'record'},
    );
    expect(SourceDailyCheckInCapability.parseDailyCheckInMap(''), isEmpty);
    expect(
      SourceDailyCheckInCapability.looksLikeAlreadyCheckedInMessage(
        'Already checked in',
      ),
      isTrue,
    );
    expect(
      SourceDailyCheckInCapability.looksLikeAlreadyCheckedInMessage('今天已签到'),
      isTrue,
    );
  });

  test('reads Picacg punch state variants and redacts sensitive headers', () {
    expect(
      SourceDailyCheckInCapability.extractPicacgIsPunched('{"isPunched":true}'),
      isTrue,
    );
    expect(
      SourceDailyCheckInCapability.extractPicacgIsPunched(
        '{"data":{"user":{"isPunched":"false"}}}',
      ),
      isFalse,
    );
    expect(SourceDailyCheckInCapability.extractPicacgIsPunched('{}'), isNull);
    expect(
      SourceDailyCheckInCapability.redactPicacgHeaders({
        'authorization': 'token',
        'signature': 'secret',
        'accept': 'json',
      }),
      {
        'authorization': '<redacted>',
        'signature': '<redacted>',
        'accept': 'json',
      },
    );
  });

  test(
    'skips check-in without initializing an unsupported active source',
    () async {
      final capability = SourceDailyCheckInCapability(
        runtimeHost: SourceRuntimeHost(
          catalog: const [
            SourceCatalogEntry(
              key: 'copy_manga',
              name: 'CopyManga',
              fileName: 'copy_manga.js',
            ),
          ],
          defaultSourceKey: 'copy_manga',
          secureSessionStorage: MemorySourceSecureSessionStorage(),
          ensureSourceInitialized: (_) async {
            throw StateError('should_not_initialize');
          },
          currentAccountForSource: (_) => null,
          isLoggedForSource: (_) => false,
        ),
        reloginCoordinator: SourceReloginCoordinator(
          loginWithStoredAccount:
              (_, {required account, required password}) async {},
        ),
      );

      expect(await capability.isCompletedToday(), isFalse);
      expect((await capability.perform()).isSkipped, isTrue);
    },
  );
}
