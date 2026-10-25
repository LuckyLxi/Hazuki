import 'package:hazuki/shared/source_task_owner.dart';
import 'package:flutter/widgets.dart';

import 'package:hazuki/shared/preferences/hazuki_general_preferences_store.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';

class HomeProfileController extends ChangeNotifier {
  HomeProfileController({
    required SourceTaskControlGateway taskControl,
    required SourceHomeGateway sourceService,
    HazukiGeneralPreferencesStore preferences =
        const HazukiGeneralPreferencesStore(),
  }) : _readTasks = SourceTaskOwner(taskControl),
       _sourceService = sourceService,
       _preferences = preferences;

  final SourceHomeGateway _sourceService;
  final HazukiGeneralPreferencesStore _preferences;

  bool _disposed = false;
  final _sourceUi = SourceUiOwner();
  final SourceTaskOwner _readTasks;
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
    _readTasks.restart();
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
    final sourceKey = _sourceService.activeSourceKey;
    final sourceRevision = _sourceService.sourceRevision;
    bool isCurrentSync() =>
        !_disposed &&
        context.mounted &&
        revision == _profileSyncRevision &&
        sourceKey == _sourceService.activeSourceKey &&
        sourceRevision == _sourceService.sourceRevision;
    if (_sourceService.activeSourceKey?.isNotEmpty != true) {
      _username = l10n(context).homeGuestUser;
      _avatarUrl = null;
      _checkedInToday = false;
      _profileLoading = false;
      _hasCompletedProfileSync = true;
      _notify();
      return;
    }

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
    _username = _sourceService.currentAccount ?? strings.homeGuestUser;
    _avatarUrl = isLogged ? _sourceService.cachedAvatarUrl : null;
    _profileLoading = false;
    _notify();
    String? avatar = _avatarUrl;
    if (isLogged) {
      try {
        avatar = await _sourceService.loadCurrentAvatarUrl(
          taskOrigin: _readTasks.origin(),
        );
      } catch (_) {
        avatar = _avatarUrl;
      }
    }

    if (!isCurrentSync()) {
      return;
    }

    if (!isLogged && !_hasCompletedProfileSync) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (!isCurrentSync()) {
        return;
      }
      try {
        await _sourceService.loadActiveSourcePreference();
      } catch (_) {}
      if (!isCurrentSync()) {
        return;
      }
      isLogged = _sourceService.isLogged;
      if (isLogged) {
        try {
          avatar = await _sourceService.loadCurrentAvatarUrl(
            taskOrigin: _readTasks.origin(),
          );
        } catch (_) {
          avatar = _avatarUrl;
        }
      }
      if (!isCurrentSync()) {
        return;
      }
    }

    _username = _sourceService.currentAccount ?? strings.homeGuestUser;
    _avatarUrl = _sourceService.isLogged
        ? (avatar ?? _sourceService.cachedAvatarUrl)
        : null;
    _profileLoading = false;
    _hasCompletedProfileSync = true;
    _notify();
    if (context.mounted) {
      await refreshCheckInState(context);
    }
  }

  Future<void> loadFirstUseText(BuildContext context) async {
    final firstUseRaw = await _preferences.loadOrInitFirstUseDate();

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
    _autoCheckInEnabled = await _preferences.loadAutoCheckInEnabled();
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
      final checked = await _sourceService.isDailyCheckInCompletedToday(
        taskOrigin: _readTasks.origin(),
      );
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
    final interaction = SourceUiScope.current;
    try {
      _sourceUi.restart();
      final result = triggeredAutomatically
          ? await SourceUiScope.withoutInteraction(
              _sourceService.performDailyCheckIn,
            )
          : interaction?.available == true
          ? await Future.any<DailyCheckInResult>([
              _sourceService.performDailyCheckIn(),
              interaction!.whenCancelled.then<DailyCheckInResult>(
                (_) =>
                    throw interaction.failure ??
                        SourceUiCancelled(interaction.reason ?? 'ownerGone'),
              ),
            ])
          : await _sourceUi.run(_sourceService.performDailyCheckIn);
      if (!context.mounted || _disposed || interaction?.available == false) {
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
      if ((isSourceUiCancellation(error) || isSourceTaskCancellation(error))) {
        return;
      }
      if (!context.mounted || _disposed || interaction?.available == false) {
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
    _readTasks.restart();
    _profileSyncRevision++;
    _authVersion++;
    _profileLoading = true;
    _notify();
  }

  void applyLoginProfile({
    required String username,
    required String avatarUrl,
  }) {
    if (_disposed) return;
    // The login dialog has already resolved this profile. Publish the same
    // result and invalidate any older synchronization still awaiting startup.
    _profileSyncRevision++;
    _username = username;
    _avatarUrl = avatarUrl.trim().isEmpty ? null : avatarUrl.trim();
    _profileLoading = false;
    _hasCompletedProfileSync = true;
    _notify();
  }

  void markLoggedOut() {
    _readTasks.restart();
    _profileSyncRevision++;
    _authVersion++;
    _checkedInToday = false;
    _avatarUrl = null;
    _profileLoading = false;
    _hasCompletedProfileSync = true;
    _notify();
  }

  void resetStartupCheckInAttempt() {
    _didAttemptStartupCheckIn = false;
  }

  void markSourceChanged() {
    _readTasks.restart(SourceTaskStopReason.sourceChanged);
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
    _readTasks.dispose();
    _sourceUi.dispose();
    _disposed = true;
    _profileSyncRevision++;
    super.dispose();
  }
}
