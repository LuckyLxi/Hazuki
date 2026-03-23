part of '../../main.dart';

class ReadingSettingsPage extends StatefulWidget {
  const ReadingSettingsPage({super.key});

  @override
  State<ReadingSettingsPage> createState() => _ReadingSettingsPageState();
}

class _ReadingSettingsPageState extends State<ReadingSettingsPage> {
  _ReaderMode _readerMode = _ReaderMode.topToBottom;
  bool _tapToTurnPage = false;
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
      _readerMode = _readerModeFromRaw(prefs.getString('reader_reading_mode'));
      _tapToTurnPage = prefs.getBool('reader_tap_to_turn_page') ?? false;
      _immersiveMode = prefs.getBool('reader_immersive_mode') ?? true;
      _keepScreenOn = prefs.getBool('reader_keep_screen_on') ?? true;
      _customBrightness = prefs.getBool('reader_custom_brightness') ?? false;
      _brightnessValue = prefs.getDouble('reader_brightness_value') ?? 0.5;
      _pinchToZoom = prefs.getBool('reader_pinch_to_zoom') ?? false;
      _longPressToSave = prefs.getBool('reader_long_press_save') ?? false;
    });
  }

  Future<void> _updateReaderMode(_ReaderMode? value) async {
    if (value == null) {
      return;
    }
    setState(() {
      _readerMode = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_reading_mode', value.prefsValue);
  }

  Future<void> _toggleTapToTurnPage(bool value) async {
    setState(() => _tapToTurnPage = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reader_tap_to_turn_page', value);
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
    final strings = l10n(context);
    final brightnessText = (_brightnessValue * 100).round().toString();
    final sliderActiveColor = Theme.of(context).colorScheme.primary;
    final sliderInactiveColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.24);

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.readingSettingsTitle),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.chrome_reader_mode_outlined),
            title: Text(strings.readingModeTitle),
            subtitle: Text(strings.readingModeSubtitle),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<_ReaderMode>(
                value: _readerMode,
                borderRadius: BorderRadius.circular(18),
                onChanged: _updateReaderMode,
                items: [
                  DropdownMenuItem(
                    value: _ReaderMode.topToBottom,
                    child: Text(strings.readingModeTopToBottom),
                  ),
                  DropdownMenuItem(
                    value: _ReaderMode.rightToLeft,
                    child: Text(strings.readingModeRightToLeft),
                  ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.touch_app_outlined),
            title: Text(strings.readingTapToTurnPageTitle),
            subtitle: Text(strings.readingTapToTurnPageSubtitle),
            value: _tapToTurnPage,
            onChanged: _readerMode == _ReaderMode.rightToLeft
                ? _toggleTapToTurnPage
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fullscreen_outlined),
            title: Text(strings.readingImmersiveModeTitle),
            subtitle: Text(strings.readingImmersiveModeSubtitle),
            value: _immersiveMode,
            onChanged: _toggleImmersiveMode,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait_outlined),
            title: Text(strings.readingKeepScreenOnTitle),
            subtitle: Text(strings.readingKeepScreenOnSubtitle),
            value: _keepScreenOn,
            onChanged: _toggleKeepScreenOn,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.brightness_medium_outlined),
            title: Text(strings.readingCustomBrightnessTitle),
            subtitle: Text(strings.readingCustomBrightnessSubtitle),
            value: _customBrightness,
            onChanged: _toggleCustomBrightness,
          ),
          ListTile(
            leading: Icon(
              Icons.wb_sunny_outlined,
              color: _customBrightness
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            title: Text(
              strings.readingBrightnessLabel(brightnessText),
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
            title: Text(strings.readingPinchToZoomTitle),
            subtitle: Text(strings.readingPinchToZoomSubtitle),
            value: _pinchToZoom,
            onChanged: _togglePinchToZoom,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save_alt_outlined),
            title: Text(strings.readingLongPressSaveTitle),
            subtitle: Text(strings.readingLongPressSaveSubtitle),
            value: _longPressToSave,
            onChanged: _toggleLongPressToSave,
          ),
        ],
      ),
    );
  }
}
