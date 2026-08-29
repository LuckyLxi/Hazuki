import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'package:hazuki/app/app_settings_store.dart';
import 'package:hazuki/app/appearance_settings.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/runtime/source_runtime_registry.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/manga_download/manga_download_storage_support.dart';
import 'package:hazuki/services/password_lock_service.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
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

  const settingsStore = HazukiAppSettingsStore();
  final appearanceFuture = settingsStore.loadAppearance();
  final localeFuture = settingsStore.loadLocalePreference();
  final useSystemTitleBarFuture = settingsStore.loadUseSystemTitleBar();
  final sourcePreferenceFuture = sl<SourceRuntimeRegistry>()
      .loadActiveSourcePreference();

  // These startup reads are independent. Running them together keeps the
  // native launch screen visible for the slowest task instead of their sum.
  await Future.wait<void>([
    loadHazukiUiFlags(),
    sourcePreferenceFuture,
    sourcePreferenceFuture
        .then((_) => sl<SourceDebugGateway>().loadSoftwareLogCaptureEnabled())
        .then((_) {}),
    _ensureAndroidNoMediaMarker(),
    sl<MangaDownloadService>().ensureInitialized(),
    sl<PasswordLockService>().ensureInitialized(),
    sl<CommentFilterService>().load(),
    appearanceFuture.then(
      (appearance) =>
          HazukiLiquidGlass.initialize(enabled: appearance.liquidGlassEnabled),
    ),
    if (Platform.isWindows)
      useSystemTitleBarFuture.then(
        (useSystemTitleBar) =>
            _initWindowsWindow(useSystemTitleBar: useSystemTitleBar),
      ),
  ]);

  final initialAppearance = await appearanceFuture;
  final initialLocale = await localeFuture;
  final initialUseSystemTitleBar = await useSystemTitleBarFuture;

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
