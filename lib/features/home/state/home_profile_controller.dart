import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';

class HomeProfileController extends ChangeNotifier {
  HomeProfileController({required HazukiSourceService sourceService})
    : _sourceService = sourceService;

  static const _firstUseDateKey = 'app_first_use_date';

  final HazukiSourceService _sourceService;

  bool _disposed = false;
  String _username = '';
  String? _avatarUrl;
  String _firstUseText = '';
  int _authVersion = 0;
  bool _autoCheckInEnabled = false;
  bool _didAttemptStartupCheckIn = false;
  bool _checkInBusy = false;
  bool _checkedInToday = false;

  String get username => _username;
  String? get avatarUrl => _avatarUrl;
  String get firstUseText => _firstUseText;
  int get authVersion => _authVersion;
  bool get autoCheckInEnabled => _autoCheckInEnabled;
  bool get checkInBusy => _checkInBusy;
  bool get checkedInToday => _checkedInToday;
  bool get isLogged => _sourceService.isLogged;
  bool get isCheckInAvailable => _sourceService.isActiveJmSource;

  Future<void> syncUserProfile(BuildContext context) async {
    // 确保不在 initState() 内同步访问 InheritedWidget（如 l10n），
    // 通过让出微任务将执行推迟到帧回调完成之后
    await Future<void>.value();
    // 异步等待后检查 context 是否仍然有效，防止 use_build_context_synchronously 警告
    if (!context.mounted) return;
    if (!_sourceService.isInitialized) {
      _username = l10n(context).homeGuestUser;
      _avatarUrl = null;
      _notify();
      return;
    }

    final strings = l10n(context);
    final username = _sourceService.currentAccount ?? strings.homeGuestUser;
    String? avatar;
    if (_sourceService.isLogged) {
      try {
        avatar = await _sourceService.loadCurrentAvatarUrl();
      } catch (_) {
        avatar = null;
      }
    }

    if (!context.mounted) {
      return;
    }

    _username = username;
    _avatarUrl = avatar;
    _notify();
    await refreshCheckInState(context);
  }

  Future<void> loadFirstUseText(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    var firstUseRaw = prefs.getString(_firstUseDateKey);

    if (firstUseRaw == null || firstUseRaw.isEmpty) {
      firstUseRaw = DateTime.now().toIso8601String();
      await prefs.setString(_firstUseDateKey, firstUseRaw);
    }

    if (!context.mounted) {
      return;
    }

    final strings = l10n(context);
    final firstUse = DateTime.tryParse(firstUseRaw)?.toLocal();
    _firstUseText = firstUse == null
        ? strings.homeFirstUseUnknown
        : strings.homeFirstUseFormatted(
            '${firstUse.year}-${firstUse.month.toString().padLeft(2, '0')}-${firstUse.day.toString().padLeft(2, '0')}',
          );
    _notify();
  }

  Future<void> loadOtherSettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    _autoCheckInEnabled =
        prefs.getBool(hazukiAutoCheckInEnabledPreferenceKey) ?? false;
    _notify();
    if (_autoCheckInEnabled && context.mounted) {
      await maybeAutoCheckInOnStartup(context);
    }
  }

  Future<void> refreshCheckInState(BuildContext context) async {
    if (!_sourceService.isActiveJmSource || !_sourceService.isLogged) {
      _checkedInToday = false;
      _notify();
      return;
    }

    try {
      final checked = await _sourceService.isDailyCheckInCompletedToday();
      if (!context.mounted) {
        return;
      }
      _checkedInToday = checked;
      _notify();
    } catch (_) {}
  }

  Future<void> maybeAutoCheckInOnStartup(BuildContext context) async {
    if (!_sourceService.isActiveJmSource) {
      return;
    }
    if (_didAttemptStartupCheckIn) {
      return;
    }
    _didAttemptStartupCheckIn = true;

    try {
      await _sourceService.ensureInitialized();
    } catch (_) {
      return;
    }

    if (!context.mounted ||
        !_autoCheckInEnabled ||
        !_sourceService.isActiveJmSource ||
        !_sourceService.isLogged ||
        _checkInBusy) {
      return;
    }

    await performCheckIn(context, triggeredAutomatically: true);
  }

  Future<void> performCheckIn(
    BuildContext context, {
    required bool triggeredAutomatically,
  }) async {
    if (_checkInBusy || !_sourceService.isActiveJmSource) {
      return;
    }

    _checkInBusy = true;
    _notify();
    try {
      final result = await _sourceService.performDailyCheckIn();
      if (!context.mounted) {
        return;
      }
      if (result.isSuccess || result.isAlreadyCheckedIn) {
        _checkedInToday = true;
        _notify();
      }
      final promptMessage = result.isSuccess
          ? l10n(context).homeCheckInSuccess
          : result.isAlreadyCheckedIn
          ? l10n(context).homeCheckInAlreadyDone
          : (result.message?.trim().isNotEmpty ?? false)
          ? result.message!.trim()
          : l10n(context).homeCheckInAlreadyDone;
      await showHazukiPrompt(context, promptMessage);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      await showHazukiPrompt(
        context,
        l10n(context).homeCheckInFailed('$error'),
        isError: true,
      );
    } finally {
      _checkInBusy = false;
      _notify();
    }
  }

  void markAuthChanged() {
    _authVersion++;
    _notify();
  }

  void markLoggedOut() {
    _authVersion++;
    _checkedInToday = false;
    _notify();
  }

  void resetStartupCheckInAttempt() {
    _didAttemptStartupCheckIn = false;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
