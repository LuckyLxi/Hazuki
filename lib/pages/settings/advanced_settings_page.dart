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
  bool _softwareLogCaptureEnabled = false;
  bool _hasCustomEditedSource = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCustomEditedSource =
        await HazukiSourceService.instance.hasCustomEditedJmSource();
    final softwareLogCaptureEnabled = await HazukiSourceService.instance
        .loadSoftwareLogCaptureEnabled();
    if (!mounted) return;
    setState(() {
      _comicIdSearchEnhance = prefs.getBool(_keyComicIdSearchEnhance) ?? false;
      _noImageMode = prefs.getBool(_noImageModeKey) ?? false;
      _softwareLogCaptureEnabled = softwareLogCaptureEnabled;
      _hasCustomEditedSource = hasCustomEditedSource;
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

  Future<void> _toggleSoftwareLogCaptureEnabled(bool value) async {
    setState(() => _softwareLogCaptureEnabled = value);
    await HazukiSourceService.instance.setSoftwareLogCaptureEnabled(value);
  }

  Future<void> _refreshCustomEditedSourceState() async {
    final hasCustomEditedSource =
        await HazukiSourceService.instance.hasCustomEditedJmSource();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasCustomEditedSource = hasCustomEditedSource;
    });
  }

  Future<void> _openComicSourceEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ComicSourceEditorPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _refreshCustomEditedSourceState();
  }

  Future<void> _restoreComicSource() async {
    final restored = await showComicSourceRestoreDialog(context);
    if (!mounted || !restored) {
      return;
    }
    await _refreshCustomEditedSourceState();
    if (!mounted) {
      return;
    }
    final strings = l10n(context);
    await showHazukiPrompt(
      context,
      strings.advancedRestoreSourceSuccess,
    );
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
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(strings.advancedDebugTitle),
                  subtitle: Text(strings.advancedDebugSubtitle),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LogsPage(),
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.bug_report_outlined),
                  title: Text(strings.advancedSoftwareLogCaptureTitle),
                  subtitle: Text(strings.advancedSoftwareLogCaptureSubtitle),
                  value: _softwareLogCaptureEnabled,
                  onChanged: _toggleSoftwareLogCaptureEnabled,
                ),
                ListTile(
                  leading: const Icon(Icons.javascript_rounded),
                  title: Text(strings.advancedEditSourceTitle),
                  subtitle: Text(strings.advancedEditSourceSubtitle),
                  onTap: _openComicSourceEditor,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: child,
                      ),
                    );
                  },
                  child: _hasCustomEditedSource
                      ? Padding(
                          key: const ValueKey<String>('restore-comic-source'),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: FilledButton.tonalIcon(
                            onPressed: _restoreComicSource,
                            icon: const Icon(Icons.restore_rounded),
                            label: Text(strings.advancedRestoreSourceLabel),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              alignment: Alignment.centerLeft,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey<String>('restore-comic-source-empty'),
                        ),
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
