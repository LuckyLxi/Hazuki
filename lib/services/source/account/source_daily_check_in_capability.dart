import 'dart:convert';

import '../models/source_contract_models.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';
import 'source_relogin_coordinator.dart';

/// Performs daily check-in workflows through explicit source-runtime access.
class SourceDailyCheckInCapability {
  SourceDailyCheckInCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceReloginCoordinator reloginCoordinator,
  }) : _runtimeHost = runtimeHost,
       _reloginCoordinator = reloginCoordinator;

  final SourceRuntimeHost _runtimeHost;
  final SourceReloginCoordinator _reloginCoordinator;

  HazukiSourceFacade get _facade => _runtimeHost.activeHandle.facade;

  static String dailyCheckInDateTag(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic> parseDailyCheckInMap(String raw) {
    if (raw.trim().isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(raw);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
  }

  static bool looksLikeAlreadyCheckedInMessage(String message) {
    final lower = message.trim().toLowerCase();
    return lower.contains('already checked') ||
        message.contains('已签到') ||
        message.contains('今天已签');
  }

  bool get _supports => _runtimeHost.supportsDailyCheckIn;
  Future<bool> isCompletedToday() async {
    if (!_supports) return false;
    final facade = _facade;
    await facade.ensureInitialized();
    if (!facade.isLogged) return false;
    final result = await facade.js.resolve(
      facade.js.engine!.evaluate(
        'this.__hazuki_source.account?.checkInStatus?.()',
      ),
    );
    if (result is bool) return result;
    return facade.loadSourceData(facade.sourceKey, 'lastCheckInDate') ==
        dailyCheckInDateTag(DateTime.now());
  }

  Future<DailyCheckInResult> perform() async {
    if (!_supports || !_facade.isLogged) {
      return const DailyCheckInResult.skipped();
    }
    final facade = _facade;
    await facade.ensureInitialized();
    final result = await _reloginCoordinator.runWithReloginRetry(
      () => facade.js.resolve(
        facade.js.engine!.evaluate('this.__hazuki_source.account.checkIn()'),
      ),
      context: SourceFacadeReloginContext(facade),
    );
    if (result is! Map) throw StateError('plugin_invalid_check_in_result');
    final message = result['message']?.toString();
    if (result['status'] == 'skipped') {
      return const DailyCheckInResult.skipped();
    }
    if (result['status'] != 'success' &&
        result['status'] != 'alreadyCheckedIn') {
      throw StateError('plugin_invalid_check_in_result');
    }
    await facade.saveSourceData(
      facade.sourceKey,
      'lastCheckInDate',
      dailyCheckInDateTag(DateTime.now()),
    );
    return result['status'] == 'alreadyCheckedIn'
        ? DailyCheckInResult.alreadyCheckedIn(message)
        : DailyCheckInResult.success(message);
  }
}
