import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../services/password_lock_service.dart';
import '../../widgets/widgets.dart';
import 'password_lock_pages.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  static const _channel = MethodChannel('hazuki.comics/privacy');

  bool _blurBackground = false;
  bool _biometricAuth = false;
  bool _authOnResume = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final dynamic result = await _channel.invokeMethod('getPrivacySettings');
      if (result is Map) {
        await PasswordLockService.instance.refreshPrivacySettings();
        if (!mounted) {
          return;
        }
        setState(() {
          _blurBackground = result['blurBackground'] == true;
          _biometricAuth = result['biometricAuth'] == true;
          _authOnResume = result['authOnResume'] == true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleBlurBackground(bool value) async {
    setState(() => _blurBackground = value);
    try {
      await _channel.invokeMethod('setBlurBackground', {'enabled': value});
    } catch (_) {}
  }

  Future<void> _toggleBiometricAuth(bool value) async {
    if (value) {
      try {
        final success = await _channel.invokeMethod('authenticate');
        if (success != true) {
          return;
        }
      } catch (_) {
        return;
      }
    }

    setState(() {
      _biometricAuth = value;
      if (!value) {
        _authOnResume = false;
      }
    });
    try {
      await _channel.invokeMethod('setBiometricAuth', {'enabled': value});
      if (!value) {
        await _channel.invokeMethod('setAuthOnResume', {'enabled': false});
      }
    } catch (_) {}
    await PasswordLockService.instance.refreshPrivacySettings();
  }

  Future<void> _toggleAuthOnResume(bool value) async {
    if (!_biometricAuth) return;
    setState(() => _authOnResume = value);
    try {
      await _channel.invokeMethod('setAuthOnResume', {'enabled': value});
    } catch (_) {}
    await PasswordLockService.instance.refreshPrivacySettings();
  }

  Future<void> _handlePasswordLockTap() async {
    await PasswordLockService.instance.ensureInitialized();
    if (!mounted) {
      return;
    }
    final service = PasswordLockService.instance;
    if (!service.isEnabled) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const PasswordLockIntroPage()),
      );
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final strings = AppLocalizations.of(context)!;
    final shouldDisable = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: AlertDialog(
              title: Text(strings.privacyPasswordLockDisableTitle),
              content: Text(strings.privacyPasswordLockDisableContent),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(strings.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(strings.commonConfirm),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scaleAnimation = Tween<double>(
          begin: 0.94,
          end: 1,
        ).animate(curvedAnimation);
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curvedAnimation);
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          ),
        );
      },
    );
    if (shouldDisable != true) {
      return;
    }
    await service.disable();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Widget _buildGroup(BuildContext context, {required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.privacySettingsTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildGroup(
                  context,
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.blur_on_outlined),
                      title: Text(strings.privacyBlurTaskTitle),
                      subtitle: Text(strings.privacyBlurTaskSubtitle),
                      value: _blurBackground,
                      onChanged: _toggleBlurBackground,
                    ),
                  ],
                ),
                _buildGroup(
                  context,
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint_outlined),
                      title: Text(strings.privacyBiometricUnlockTitle),
                      subtitle: Text(strings.privacyBiometricUnlockSubtitle),
                      value: _biometricAuth,
                      onChanged: _toggleBiometricAuth,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.lock_clock_outlined),
                      title: Text(strings.privacyAuthOnResumeTitle),
                      subtitle: Text(strings.privacyAuthOnResumeSubtitle),
                      value: _authOnResume,
                      onChanged: _biometricAuth ? _toggleAuthOnResume : null,
                    ),
                    ListTile(
                      leading: const Icon(Icons.password_rounded),
                      title: Text(strings.privacyPasswordLockTitle),
                      subtitle: Text(
                        PasswordLockService.instance.isEnabled
                            ? strings.privacyPasswordLockEnabledSubtitle
                            : strings.privacyPasswordLockDisabledSubtitle,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _handlePasswordLockTap,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
