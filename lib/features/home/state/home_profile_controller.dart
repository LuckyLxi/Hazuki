import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';

class HomeProfileController extends ChangeNotifier {
  HomeProfileController({required SourceHomeGateway sourceService})
    : _sourceService = sourceService;

  final SourceHomeGateway _sourceService;

  bool _disposed = false;
  String _username = '';
  String? _avatarUrl;
  String _firstUseText = '';
  int _authVersion = 0;
  bool _autoCheckInEnabled = false;
  bool _didAttemptStartupCheckIn = false;
  bool _checkInBusy = false;
  bool _checkedInToday = false;
  bool _profileLoading = true;
  bool _hasCompletedProfileSync = false;
  int _profileSyncRevision = 0;

  String get username => _username;
  String? get avatarUrl => _avatarUrl;
  String get firstUseText => _firstUseText;
  int get authVersion => _authVersion;
  bool get autoCheckInEnabled => _autoCheckInEnabled;
  bool get checkInBusy => _checkInBusy;
  bool get checkedInToday => _checkedInToday;
  bool get profileLoading => _profileLoading;
  bool get isLogged => _sourceService.isLogged;
  bool get isCheckInAvailable => _sourceService.isActiveDailyCheckInSource;

  Future<void> syncUserProfile(BuildContext context) async {
    final revision = ++_profileSyncRevision;
    _profileLoading = true;
    _notify();
    // 确保不在 initState() 内同步访问 InheritedWidget（如 l10n），
    // 通过让出微任务将执行推迟到帧回调完成之后
    await Future<void>.value();
    try {
      await _sourceService.loadActiveSourcePreference();
    } catch (_) {}
    // 异步等待后检查 context 是否仍然有效，防止 use_build_context_synchronously 警告
    if (!context.mounted || revision != _profileSyncRevision) return;
    if (!_sourceService.isInitialized) {
      final strings = l10n(context);
      _profileLoading =
          !_sourceService.runtimeState.hasFailure &&
          !_sourceService.runtimeState.isWaitingForRestart;
      _username = _profileLoading
          ? strings.commonLoading
          : (_sourceService.currentAccount ?? strings.homeGuestUser);
      _avatarUrl = null;
      _notify();
      return;
    }

    final strings = l10n(context);
    var isLogged = _sourceService.isLogged;
    var username = _sourceService.currentAccount ?? strings.homeGuestUser;
    String? avatar;
    if (isLogged) {
      try {
        avatar = await _sourceService.loadCurrentAvatarUrl();
      } catch (_) {
        avatar = null;
      }
    }

    if (!context.mounted || revision != _profileSyncRevision) {
      return;
    }

    if (!isLogged && !_hasCompletedProfileSync) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (!context.mounted || revision != _profileSyncRevision) {
        return;
      }
      try {
        await _sourceService.loadActiveSourcePreference();
      } catch (_) {}
      if (!context.mounted || revision != _profileSyncRevision) {
        return;
      }
      isLogged = _sourceService.isLogged;
      username = _sourceService.currentAccount ?? strings.homeGuestUser;
      if (isLogged) {
        try {
          avatar = await _sourceService.loadCurrentAvatarUrl();
        } catch (_) {
          avatar = null;
        }
      }
      if (!context.mounted || revision != _profileSyncRevision) {
        return;
      }
    }

    _username = username;
    _avatarUrl = avatar;
    _profileLoading = false;
    _hasCompletedProfileSync = true;
    _notify();
    await refreshCheckInState(context);
  }

  Future<void> loadFirstUseText(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    var firstUseRaw = prefs.getString(hazukiFirstUseDatePreferenceKey);

    if (firstUseRaw == null || firstUseRaw.isEmpty) {
      firstUseRaw = DateTime.now().toIso8601String();
      await prefs.setString(hazukiFirstUseDatePreferenceKey, firstUseRaw);
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
    if (!_sourceService.isActiveDailyCheckInSource ||
        !_sourceService.isLogged) {
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
    if (!_sourceService.isActiveDailyCheckInSource) {
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
        !_sourceService.isActiveDailyCheckInSource ||
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
    if (_checkInBusy || !_sourceService.isActiveDailyCheckInSource) {
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
    _profileSyncRevision++;
    _authVersion++;
    _profileLoading = true;
    _notify();
  }

  void markLoggedOut() {
    _profileSyncRevision++;
    _authVersion++;
    _checkedInToday = false;
    _profileLoading = false;
    _hasCompletedProfileSync = true;
    _notify();
  }

  void resetStartupCheckInAttempt() {
    _didAttemptStartupCheckIn = false;
  }

  void markSourceChanged() {
    _profileSyncRevision++;
    _authVersion++;
    _profileLoading = true;
    _avatarUrl = null;
    _hasCompletedProfileSync = false;
    _notify();
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
