import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/home/support/home_profile_actions.dart';
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

  AppLocalizations get _strings => l10n(context);

  @override
  void initState() {
    super.initState();
    _registry.addListener(_handleSourceChanged);
    _sourceService.addListener(_handleSourceChanged);
    unawaited(_registry.loadActiveSourcePreference());
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

  Future<HomeLoginDialogProfile> _login(String account, String password) async {
    await _sourceService.login(account: account, password: password);
    final avatarUrl = (await _sourceService.loadCurrentAvatarUrl()) ?? '';
    return HomeLoginDialogProfile(
      username: _sourceService.currentAccount ?? account,
      avatarUrl: avatarUrl.trim(),
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
    final account = _registry.currentAccountForSource(key);
    final busy = _busySourceKey == key;
    final subtitle = account == null
        ? _strings.labSourceAccountLoggedOut
        : _strings.labSourceAccountLoggedInAs(account);

    return ListTile(
      leading: Icon(
        active ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(source.name),
      subtitle: Text('${source.key} · $subtitle'),
      trailing: active
          ? FilledButton(
              onPressed: _busySourceKey == null
                  ? (_sourceService.isLogged ? _logout : _showLoginDialog)
                  : null,
              child: Text(
                _sourceService.isLogged
                    ? _strings.labSourceAccountLogout
                    : _strings.labSourceAccountLogin,
              ),
            )
          : TextButton(
              onPressed: busy ? null : () => _switchSource(source),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_strings.labSourceAccountSwitch),
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
