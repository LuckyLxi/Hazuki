part of '../../main.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
  });

  final AppearanceSettingsData appearanceSettings;
  final Future<void> Function(AppearanceSettingsData next) onAppearanceChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.cached_outlined),
            title: const Text('缓存'),
            subtitle: const Text('缓存相关设置'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CacheSettingsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('外观'),
            subtitle: const Text('软件界面相关设置'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppearanceSettingsPage(
                    appearanceSettings: appearanceSettings,
                    onAppearanceChanged: onAppearanceChanged,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: const Text('阅读'),
            subtitle: const Text('阅读器设置'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ReadingSettingsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('隐私'),
            subtitle: const Text('隐私相关功能'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacySettingsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('云同步'),
            subtitle: const Text('上传与恢复备份'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CloudSyncPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_applications_outlined),
            title: const Text('高级'),
            subtitle: const Text('实验性功能'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdvancedSettingsPage(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('Hazuki'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AboutPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
