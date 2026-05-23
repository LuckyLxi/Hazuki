import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/home/support/home_profile_actions.dart';
import 'package:hazuki/features/home/support/home_source_account_login.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../settings_group.dart';

class SourceAccountLabPage extends StatefulWidget {
  const SourceAccountLabPage({super.key});

  @override
  State<SourceAccountLabPage> createState() => _SourceAccountLabPageState();
}

class _SourceAccountLabPageState extends State<SourceAccountLabPage> {
  final SourceRuntimeRegistry _registry = sl<SourceRuntimeRegistry>();
  final HazukiSourceService _sourceService = sl<HazukiSourceService>();
  String? _busySourceKey;
  String? _downloadingSourceKey;
  double? _downloadProgress;
  final Map<String, bool> _sourceInstalled = <String, bool>{};

  AppLocalizations get _strings => l10n(context);

  @override
  void initState() {
    super.initState();
    _registry.addListener(_handleSourceChanged);
    _sourceService.addListener(_handleSourceChanged);
    unawaited(_registry.loadActiveSourcePreference());
    unawaited(_refreshSourceInstallStates());
  }

  @override
  void dispose() {
    _registry.removeListener(_handleSourceChanged);
    _sourceService.removeListener(_handleSourceChanged);
    super.dispose();
  }

  void _handleSourceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshSourceInstallStates() async {
    final updates = <String, bool>{};
    for (final source in _registry.allowedSources) {
      updates[source.normalizedKey] = await _sourceService.hasLocalSourceFile(
        source.normalizedKey,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _sourceInstalled
        ..clear()
        ..addAll(updates);
    });
  }

  Future<void> _switchSource(SourceCatalogEntry source) async {
    if (_busySourceKey != null ||
        source.normalizedKey == _registry.activeSourceKey) {
      return;
    }
    setState(() => _busySourceKey = source.normalizedKey);
    try {
      await _registry.activateSource(source.normalizedKey);
      await _sourceService.ensureInitialized(sourceKey: source.normalizedKey);
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(context, _strings.labSourceAccountSwitchSuccess);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(
        context,
        _strings.labSourceAccountSwitchFailed('$error'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busySourceKey = null);
      }
    }
  }

  Future<void> _downloadSource(SourceCatalogEntry source) async {
    if (_busySourceKey != null || _downloadingSourceKey != null) {
      return;
    }
    setState(() {
      _busySourceKey = source.normalizedKey;
      _downloadingSourceKey = source.normalizedKey;
      _downloadProgress = null;
    });
    var downloaded = false;
    try {
      await _sourceService.downloadSourceFile(
        source.normalizedKey,
        onProgress: (received, total) {
          if (!mounted ||
              total <= 0 ||
              _downloadingSourceKey != source.normalizedKey) {
            return;
          }
          setState(() {
            _downloadProgress = (received / total).clamp(0.0, 1.0);
          });
        },
      );
      downloaded = true;
      if (!mounted) {
        return;
      }
      setState(() {
        _sourceInstalled[source.normalizedKey] = true;
      });
      await _sourceService.ensureInitialized(sourceKey: source.normalizedKey);
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(context, _strings.labSourceAccountDownloadSuccess);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(
        context,
        downloaded
            ? _strings.labSourceAccountSwitchFailed('$error')
            : _strings.labSourceAccountDownloadFailed('$error'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busySourceKey = null;
          _downloadingSourceKey = null;
          _downloadProgress = null;
        });
        unawaited(_refreshSourceInstallStates());
      }
    }
  }

  Future<HomeLoginDialogProfile> _login(String account, String password) async {
    return loginSourceAccountForDialog(
      sourceService: _sourceService,
      account: account,
      password: password,
    );
  }

  Future<void> _showLoginDialog() async {
    final avatarUrl = _sourceService.isLogged
        ? await _sourceService.loadCurrentAvatarUrl()
        : null;
    if (!mounted) {
      return;
    }
    await showHomeLoginDialog(
      context,
      initialUsername:
          _sourceService.currentAccount ?? _strings.labSourceAccountLoggedOut,
      initialAvatarUrl: avatarUrl?.trim() ?? '',
      firstUseText: '',
      onLogin: _login,
      onLogoutTap: () {
        unawaited(_logout());
      },
      onRequestSaveAvatar: (_) async {},
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    if (!_sourceService.isLogged) {
      return;
    }
    final confirmed = await showHomeLogoutConfirmDialog(context);
    if (!confirmed) {
      return;
    }
    await _sourceService.logout();
    if (mounted) {
      setState(() {});
      await showHazukiPrompt(context, _strings.homeLoggedOut);
    }
  }

  Widget _buildSourceTile(SourceCatalogEntry source) {
    final key = source.normalizedKey;
    final active = key == _registry.activeSourceKey;
    final installed = _sourceInstalled[key] ?? (key == hazukiDefaultSourceKey);
    // 各源独立的账号信息，不依赖全局 isLogged
    final account = _registry.currentAccountForSource(key);
    final isSourceLogged = account != null;
    final busy = _busySourceKey == key;
    final downloading = _downloadingSourceKey == key;
    final accountStatus = isSourceLogged
        ? _strings.labSourceAccountLoggedInAs(account)
        : _strings.labSourceAccountLoggedOut;
    final subtitle = installed
        ? accountStatus
        : _strings.labSourceAccountNotDownloaded;

    return ListTile(
      // 点击整个 tile 切换源（非活跃已安装）或下载（未安装），活跃源点击无响应
      onTap: _busySourceKey != null || active
          ? null
          : installed
          ? () => _switchSource(source)
          : () => _downloadSource(source),
      leading: Icon(
        active ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(source.name),
      subtitle: Text('${source.key} · $subtitle'),
      trailing: !installed
          // 未安装：显示下载按钮
          ? FilledButton(
              onPressed: busy ? null : () => _downloadSource(source),
              child: downloading
                  ? _SourceDownloadProgressIndicator(
                      progress: _downloadProgress,
                    )
                  : Text(_strings.sourceUpdateDownload),
            )
          // 已安装：所有源都显示登录/取消登录按钮
          : active
          ? FilledButton(
              onPressed: _busySourceKey == null
                  ? (isSourceLogged ? _logout : _showLoginDialog)
                  : null,
              child: Text(
                isSourceLogged
                    ? _strings.labSourceAccountLogout
                    : _strings.labSourceAccountLogin,
              ),
            )
          // 非活跃源：显示按钮，但点击时提示先切换，不自动切换
          : TextButton(
              onPressed: _busySourceKey == null
                  ? () => showHazukiPrompt(
                      context,
                      _strings.labSourceAccountSwitchFirst(source.name),
                      isError: false,
                    )
                  : null,
              child: Text(
                isSourceLogged
                    ? _strings.labSourceAccountLogout
                    : _strings.labSourceAccountLogin,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(_strings.labSourceAccountTitle),
      ),
      body: HazukiSettingsPageBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SettingsGroup(
              children: [
                for (final source in _registry.allowedSources)
                  _buildSourceTile(source),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceDownloadProgressIndicator extends StatelessWidget {
  const _SourceDownloadProgressIndicator({required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final value = progress;
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        value: value?.clamp(0.0, 1.0),
      ),
    );
  }
}
