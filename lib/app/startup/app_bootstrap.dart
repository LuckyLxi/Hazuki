import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'package:hazuki/app/app_settings_store.dart';
import 'package:hazuki/app/appearance_settings.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/manga_download/manga_download_storage_support.dart';
import 'package:hazuki/services/password_lock_service.dart';
import 'package:hazuki/shared/ui_flags.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.settingsStore,
    required this.initialAppearance,
    required this.initialLocale,
    required this.initialUseSystemTitleBar,
  });

  final HazukiAppSettingsStore settingsStore;
  final AppearanceSettingsData initialAppearance;
  final Locale? initialLocale;
  final bool initialUseSystemTitleBar;
}

Future<AppBootstrapResult> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerServices();
  await loadHazukiUiFlags();
  await sl<SourceRuntimeRegistry>().loadActiveSourcePreference();
  await sl<HazukiSourceService>().loadSoftwareLogCaptureEnabled();
  await _ensureAndroidNoMediaMarker();
  await sl<MangaDownloadService>().ensureInitialized();
  await sl<PasswordLockService>().ensureInitialized();
  await sl<CommentFilterService>().load();

  const settingsStore = HazukiAppSettingsStore();
  final initialAppearance = await settingsStore.loadAppearance();
  final initialLocale = await settingsStore.loadLocalePreference();
  final initialUseSystemTitleBar = await settingsStore.loadUseSystemTitleBar();

  if (Platform.isWindows) {
    await _initWindowsWindow(useSystemTitleBar: initialUseSystemTitleBar);
  }

  return AppBootstrapResult(
    settingsStore: settingsStore,
    initialAppearance: initialAppearance,
    initialLocale: initialLocale,
    initialUseSystemTitleBar: initialUseSystemTitleBar,
  );
}

Future<void> _ensureAndroidNoMediaMarker() async {
  if (!Platform.isAndroid) {
    return;
  }
  final rootPath = await MangaDownloadAccess.loadDownloadsRootPath();
  if (rootPath.trim().isEmpty) {
    return;
  }
  try {
    final dir = Directory(rootPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final noMediaFile = File('${dir.path}/.nomedia');
    if (!await noMediaFile.exists()) {
      await noMediaFile.writeAsString('', flush: true);
    }
  } catch (_) {}
}

Future<void> _initWindowsWindow({required bool useSystemTitleBar}) async {
  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow(
    WindowOptions(
      minimumSize: const Size(960, 640),
      title: 'Hazuki',
      titleBarStyle: useSystemTitleBar
          ? TitleBarStyle.normal
          : TitleBarStyle.hidden,
      windowButtonVisibility: useSystemTitleBar,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}
