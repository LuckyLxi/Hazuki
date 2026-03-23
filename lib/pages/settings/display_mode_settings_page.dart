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
  State<DisplayModeSettingsPage> createState() =>
      _DisplayModeSettingsPageState();
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
      final strings = l10n(context);
      setState(() {
        _loading = false;
        _error = strings.displayModeAndroidOnly;
      });
      return;
    }

    try {
      final list = await _displayModeChannel.invokeMethod<List<dynamic>>(
        'getDisplayModes',
      );
      final modes = (list ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final hasCurrent = modes.any(
        (mode) => mode['raw']?.toString() == widget.currentDisplayModeRaw,
      );
      final selected = hasCurrent
          ? widget.currentDisplayModeRaw
          : 'native:auto';
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
      final strings = l10n(context);
      setState(() {
        _loading = false;
        _error = strings.displayModeReadFailed('$e');
      });
    }
  }

  Future<void> _onSelect(String raw) async {
    final strings = l10n(context);
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
        throw Exception(strings.displayModeSystemRejected);
      }
      await widget.onDisplayModeChanged(raw);
      await _loadModes();
      if (!mounted) {
        return;
      }
      unawaited(showHazukiPrompt(context, strings.displayModeApplied));
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.displayModeSetFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  String _modeLabel(BuildContext context, Map<String, dynamic> mode) {
    return mode['label']?.toString() ??
        mode['raw']?.toString() ??
        l10n(context).displayModeUnknownMode;
  }

  String _activeModeLabel(BuildContext context) {
    if (_activeRaw == null) {
      return l10n(context).displayModeUnknown;
    }
    final active = _modes.where(
      (mode) => mode['raw']?.toString() == _activeRaw,
    );
    if (active.isEmpty) {
      return _activeRaw!;
    }
    return _modeLabel(context, active.first);
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.displayRefreshRateTitle),
      ),
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
                      strings.displayModeCurrentLabel(
                        _activeModeLabel(context),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  ..._modes.map((mode) {
                    final raw = mode['raw']?.toString() ?? 'native:auto';
                    final isActive = raw == _activeRaw;
                    final isPreferred = mode['isPreferred'] == true;
                    return RadioListTile<String>(
                      value: raw,
                      title: Text(_modeLabel(context, mode)),
                      subtitle: isActive
                          ? Text(strings.displayModeCurrentSubtitle)
                          : (isPreferred
                                ? Text(strings.displayModeSelectedSubtitle)
                                : null),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(strings.displayModeHint),
                  ),
                ],
              ),
            ),
    );
  }
}
