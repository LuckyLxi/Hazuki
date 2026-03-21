part of '../../main.dart';

class ReadingSettingsPage extends StatefulWidget {
  const ReadingSettingsPage({super.key});

  @override
  State<ReadingSettingsPage> createState() => _ReadingSettingsPageState();
}

class _ReadingSettingsPageState extends State<ReadingSettingsPage> {
  bool _immersiveMode = true;
  bool _keepScreenOn = true;
  bool _customBrightness = false;
  double _brightnessValue = 0.5;
  bool _pinchToZoom = false;
  bool _longPressToSave = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _immersiveMode = prefs.getBool('reader_immersive_mode') ?? true;
      _keepScreenOn = prefs.getBool('reader_keep_screen_on') ?? true;
      _customBrightness = prefs.getBool('reader_custom_brightness') ?? false;
      _brightnessValue = prefs.getDouble('reader_brightness_value') ?? 0.5;
      _pinchToZoom = prefs.getBool('reader_pinch_to_zoom') ?? false;
      _longPressToSave = prefs.getBool('reader_long_press_save') ?? false;
    });
  }

  Future<void> _toggleImmersiveMode(bool value) async {
    setState(() => _immersiveMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reader_immersive_mode', value);
  }

  Future<void> _toggleKeepScreenOn(bool value) async {
    setState(() => _keepScreenOn = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reader_keep_screen_on', value);
  }

  Future<void> _toggleCustomBrightness(bool value) async {
    setState(() => _customBrightness = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reader_custom_brightness', value);
  }

  Future<void> _updateBrightness(double value) async {
    setState(() => _brightnessValue = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_brightness_value', value);
  }

  Future<void> _togglePinchToZoom(bool value) async {
    setState(() => _pinchToZoom = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reader_pinch_to_zoom', value);
  }

  Future<void> _toggleLongPressToSave(bool value) async {
    setState(() => _longPressToSave = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reader_long_press_save', value);
  }

  @override
  Widget build(BuildContext context) {
    final brightnessText = (_brightnessValue * 100).round().toString();
    final sliderActiveColor = Theme.of(context).colorScheme.primary;
    final sliderInactiveColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.24);

    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('阅读设置')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.fullscreen_outlined),
            title: const Text('沉浸模式'),
            subtitle: const Text('开启后进入阅读器自动隐藏状态栏和底部导航栏'),
            value: _immersiveMode,
            onChanged: _toggleImmersiveMode,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait_outlined),
            title: const Text('屏幕常亮'),
            subtitle: const Text('开启后阅读时保持屏幕常亮，不自动锁屏'),
            value: _keepScreenOn,
            onChanged: _toggleKeepScreenOn,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.brightness_medium_outlined),
            title: const Text('自定义亮度'),
            subtitle: const Text('开启后可在阅读器内按此设置覆盖系统亮度'),
            value: _customBrightness,
            onChanged: _toggleCustomBrightness,
          ),
          ListTile(
            leading: Icon(
              Icons.wb_sunny_outlined,
              color: _customBrightness
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            title: Text(
              '亮度 $brightnessText',
              style: TextStyle(
                color: _customBrightness
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
            subtitle: Slider(
              value: _brightnessValue,
              min: 0,
              max: 1,
              divisions: 100,
              onChanged: _customBrightness ? _updateBrightness : null,
              activeColor: sliderActiveColor,
              inactiveColor: sliderInactiveColor,
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.zoom_in_outlined),
            title: const Text('双指缩放'),
            subtitle: const Text('启用后可双指捏合对漫画图片进行放大查看'),
            value: _pinchToZoom,
            onChanged: _togglePinchToZoom,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save_alt_outlined),
            title: const Text('长按保存图片'),
            subtitle: const Text('启用后长按漫画图片可保存该图片'),
            value: _longPressToSave,
            onChanged: _toggleLongPressToSave,
          ),
        ],
      ),
    );
  }
}
