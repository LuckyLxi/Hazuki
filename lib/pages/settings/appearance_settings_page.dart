part of '../../main.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({
    super.key,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
  });

  final AppearanceSettingsData appearanceSettings;
  final Future<void> Function(AppearanceSettingsData next) onAppearanceChanged;

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late AppearanceSettingsData _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.appearanceSettings;
  }

  Future<void> _apply(AppearanceSettingsData next) async {
    setState(() {
      _settings = next;
    });
    await widget.onAppearanceChanged(next);
  }

  String get _themeModeLabel {
    return switch (_settings.themeMode) {
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
      _ => '跟随系统',
    };
  }

  String get _displayModeLabel {
    final raw = _settings.displayModeRaw;
    if (raw == 'native:auto') {
      return '自动';
    }
    if (raw.startsWith('native:')) {
      final id = raw.substring('native:'.length);
      return '已指定模式（ID: $id）';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            title: const Text('主题'),
            subtitle: Text(_themeModeLabel),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text('浅色'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text('深色'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text('跟随系统'),
                  icon: Icon(Icons.settings_suggest_outlined),
                ),
              ],
              selected: {_settings.themeMode},
              onSelectionChanged: (selection) {
                final mode = selection.first;
                unawaited(_apply(_settings.copyWith(themeMode: mode)));
              },
              showSelectedIcon: false,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('屏幕帧率'),
            subtitle: Text(_displayModeLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DisplayModeSettingsPage(
                    currentDisplayModeRaw: _settings.displayModeRaw,
                    onDisplayModeChanged: (displayModeRaw) {
                      return _apply(
                        _settings.copyWith(displayModeRaw: displayModeRaw),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            value: _settings.oledPureBlack,
            title: const Text('OLED 优化'),
            subtitle: const Text('开启后深色模式使用纯色背景'),
            onChanged: (value) {
              unawaited(_apply(_settings.copyWith(oledPureBlack: value)));
            },
          ),
          SwitchListTile(
            value: _settings.dynamicColor,
            title: const Text('动态取色'),
            subtitle: const Text('根据系统壁纸自动提取主题色（Android 12+）'),
            onChanged: (value) {
              unawaited(_apply(_settings.copyWith(dynamicColor: value)));
            },
          ),
          SwitchListTile(
            value: _settings.comicDetailDynamicColor,
            title: const Text('漫画详情页动态取色'),
            subtitle: const Text('开启后根据漫画封面生成漫画详情页动态主题'),
            onChanged: (value) {
              unawaited(_apply(_settings.copyWith(comicDetailDynamicColor: value)));
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              '配色方案',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List<Widget>.generate(kHazukiColorPresets.length, (
                index,
              ) {
                final preset = kHazukiColorPresets[index];
                final selected = _settings.presetIndex == index;
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 3,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      unawaited(_apply(_settings.copyWith(presetIndex: index)));
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: preset.seedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
