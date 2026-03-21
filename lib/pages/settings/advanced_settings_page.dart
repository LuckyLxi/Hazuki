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
    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('高级')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Debug'),
                  subtitle: const Text('日志'),
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
                  title: const Text('漫画 ID 搜索优化'),
                  subtitle: const Text('提交搜索时自动过滤非数字字符，仅保留阿拉伯数字作为关键词'),
                  value: _comicIdSearchEnhance,
                  onChanged: _toggleComicIdSearchEnhance,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.image_not_supported_outlined),
                  title: const Text('无图模式'),
                  subtitle: const Text('全局不显示图片（侧边栏登录头像除外）'),
                  value: _noImageMode,
                  onChanged: _toggleNoImageMode,
                ),
              ],
            ),
    );
  }
}
