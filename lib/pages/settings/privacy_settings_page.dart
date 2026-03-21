part of '../../main.dart';

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
      // Trying to authenticate before enabling it
      try {
        final success = await _channel.invokeMethod('authenticate');
        if (success != true) {
          return;
        }
      } catch (_) {
        return;
      }
    } else {
      // Turning off requires auth too for security, or we just allow it depending on threat model.
      // Let's just allow toggling off. But to actually make it safe, we could require auth, but user requested straightforward toggle.
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
  }

  Future<void> _toggleAuthOnResume(bool value) async {
    if (!_biometricAuth) return;
    setState(() => _authOnResume = value);
    try {
      await _channel.invokeMethod('setAuthOnResume', {'enabled': value});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('隐私设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.blur_on_outlined),
                  title: const Text('模糊任务栏应用页面'),
                  subtitle: const Text('切到近期任务时任务卡片显示为纯黑'),
                  value: _blurBackground,
                  onChanged: _toggleBlurBackground,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_outlined),
                  title: const Text('生物认证解锁'),
                  subtitle: const Text('每次进入软件需验证指纹'),
                  value: _biometricAuth,
                  onChanged: _toggleBiometricAuth,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_clock_outlined),
                  title: const Text('退出软件需重新验证'),
                  subtitle: const Text('即使应用在后台，只要不在前台，再次打开便需要重新认证'),
                  value: _authOnResume,
                  onChanged: _biometricAuth ? _toggleAuthOnResume : null,
                ),
              ],
            ),
    );
  }
}
