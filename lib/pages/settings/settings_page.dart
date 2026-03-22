part of '../../main.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final AppearanceSettingsData appearanceSettings;
  final Future<void> Function(AppearanceSettingsData next) onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.settingsTitle),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.cached_outlined),
            title: Text(strings.settingsCacheTitle),
            subtitle: Text(strings.settingsCacheSubtitle),
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
            title: Text(strings.settingsDisplayTitle),
            subtitle: Text(strings.settingsDisplaySubtitle),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppearanceSettingsPage(
                    appearanceSettings: appearanceSettings,
                    onAppearanceChanged: onAppearanceChanged,
                    locale: locale,
                    onLocaleChanged: onLocaleChanged,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: Text(strings.settingsReadingTitle),
            subtitle: Text(strings.settingsReadingSubtitle),
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
            title: Text(strings.settingsPrivacyTitle),
            subtitle: Text(strings.settingsPrivacySubtitle),
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
            title: Text(strings.settingsCloudSyncTitle),
            subtitle: Text(strings.settingsCloudSyncSubtitle),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CloudSyncPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_applications_outlined),
            title: Text(strings.settingsAdvancedTitle),
            subtitle: Text(strings.settingsAdvancedSubtitle),
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
            title: Text(strings.settingsAboutTitle),
            subtitle: const Text('Hazuki'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
