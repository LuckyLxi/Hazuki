import 'package:flutter/widgets.dart';
import '../../services/software_update/software_update_service.dart';
import '../../shared/software_update/software_update_dialog_presenter.dart';

export '../../shared/software_update/software_update_dialog_presenter.dart';

class SoftwareUpdateDialogSupport extends SoftwareUpdateDialogPresenter {
  const SoftwareUpdateDialogSupport({
    required super.downloadService,
    required Future<SoftwareUpdateCheckResult?> Function() checkForUpdates,
  }) : _checkForUpdates = checkForUpdates;

  final Future<SoftwareUpdateCheckResult?> Function() _checkForUpdates;

  Future<SoftwareUpdateDialogAction?> showIfNeeded({
    GlobalKey<NavigatorState>? navigatorKey,
    BuildContext? dialogContext,
    required bool Function() isMounted,
    required String skipPrefsKey,
    bool respectSkipPreference = true,
  }) async {
    final check = await _checkForUpdates();
    if (!isMounted() || check == null || !check.hasUpdate) {
      return null;
    }
    if (dialogContext != null && !dialogContext.mounted) return null;

    return showForCheck(
      navigatorKey: navigatorKey,
      dialogContext: dialogContext,
      isMounted: isMounted,
      skipPrefsKey: skipPrefsKey,
      check: check,
      respectSkipPreference: respectSkipPreference,
    );
  }
}
