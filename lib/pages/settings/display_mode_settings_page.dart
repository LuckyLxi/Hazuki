part of '../../main.dart';

class DisplayModeSettingsPage extends StatefulWidget {
  const DisplayModeSettingsPage({
    super.key,
    required this.currentDisplayModeRaw,
    required this.onDisplayModeChanged,
  });

  final String currentDisplayModeRaw;
  final Future<void> Function(String displayModeRaw) onDisplayModeChanged;

  @override
  State<DisplayModeSettingsPage> createState() => _DisplayModeSettingsPageState();
}

class _DisplayModeSettingsPageState extends State<DisplayModeSettingsPage> {
  List<Map<String, dynamic>> _modes = const [];
  String _selectedRaw = 'native:auto';
  String? _activeRaw;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadModes());
  }

  Future<void> _loadModes() async {
    if (!Platform.isAndroid) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '仅 Android 支持屏幕帧率设置';
      });
      return;
    }

    try {
      final list = await _displayModeChannel.invokeMethod<List<dynamic>>(
        'getDisplayModes',
      );
      final modes =
          (list ?? const <dynamic>[])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      final hasCurrent = modes.any(
        (mode) => mode['raw']?.toString() == widget.currentDisplayModeRaw,
      );
      final selected = hasCurrent ? widget.currentDisplayModeRaw : 'native:auto';
      final activeMode = modes.cast<Map<String, dynamic>?>().firstWhere(
        (mode) => mode?['isActive'] == true,
        orElse: () => null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _modes = modes;
        _selectedRaw = selected;
        _activeRaw = activeMode?['raw']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '读取屏幕模式失败：$e';
      });
    }
  }

  Future<void> _onSelect(String raw) async {
    setState(() {
      _selectedRaw = raw;
    });
    try {
      bool applied;
      if (raw == 'native:auto') {
        await _displayModeChannel.invokeMethod<void>('applyAutoDisplayMode');
        applied = true;
      } else {
        applied =
            await _displayModeChannel.invokeMethod<bool>(
              'applyDisplayModeRaw',
              {'raw': raw},
            ) ??
            false;
      }
      if (!applied) {
        throw Exception('系统拒绝了该显示模式');
      }
      await widget.onDisplayModeChanged(raw);
      await _loadModes();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已应用屏幕帧率，若未生效请重启应用')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('设置失败：$e')));
    }
  }

  String _modeLabel(Map<String, dynamic> mode) {
    return mode['label']?.toString() ?? mode['raw']?.toString() ?? '未知模式';
  }

  String _activeModeLabel() {
    if (_activeRaw == null) {
      return '未知';
    }
    final active = _modes.where((mode) => mode['raw']?.toString() == _activeRaw);
    if (active.isEmpty) {
      return _activeRaw!;
    }
    return _modeLabel(active.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('屏幕帧率')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            )
          : RadioGroup<String>(
              groupValue: _selectedRaw,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                unawaited(_onSelect(value));
              },
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      '当前系统模式：${_activeModeLabel()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  ..._modes.map((mode) {
                    final raw = mode['raw']?.toString() ?? 'native:auto';
                    final isActive = raw == _activeRaw;
                    final isPreferred = mode['isPreferred'] == true;
                    return RadioListTile<String>(
                      value: raw,
                      title: Text(_modeLabel(mode)),
                      subtitle: isActive
                          ? const Text('系统当前')
                          : (isPreferred ? const Text('已选择') : null),
                    );
                  }),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text('提示：部分机型会受系统省电或应用白名单策略影响。'),
                  ),
                ],
              ),
            ),
    );
  }
}
