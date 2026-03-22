part of '../../main.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  static const _keyComicIdSearchEnhance = 'advanced_comic_id_search_enhance';

  bool _comicIdSearchEnhance = false;
  bool _noImageMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _comicIdSearchEnhance = prefs.getBool(_keyComicIdSearchEnhance) ?? false;
      _noImageMode = prefs.getBool(_noImageModeKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _toggleComicIdSearchEnhance(bool value) async {
    setState(() => _comicIdSearchEnhance = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyComicIdSearchEnhance, value);
  }

  Future<void> _toggleNoImageMode(bool value) async {
    setState(() => _noImageMode = value);
    await setHazukiNoImageMode(value);
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.advancedTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(strings.advancedDebugTitle),
                  subtitle: Text(strings.advancedDebugSubtitle),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FavoritesDebugPage(),
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.tag_outlined),
                  title: Text(strings.advancedComicIdSearchTitle),
                  subtitle: Text(strings.advancedComicIdSearchSubtitle),
                  value: _comicIdSearchEnhance,
                  onChanged: _toggleComicIdSearchEnhance,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.image_not_supported_outlined),
                  title: Text(strings.advancedNoImageModeTitle),
                  subtitle: Text(strings.advancedNoImageModeSubtitle),
                  value: _noImageMode,
                  onChanged: _toggleNoImageMode,
                ),
              ],
            ),
    );
  }
}
