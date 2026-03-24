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
  bool _applying = false;
  String? _applyingRaw;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedRaw = widget.currentDisplayModeRaw;
    unawaited(_loadModes());
  }

  Future<void> _loadModes({bool showLoader = true}) async {
    if (mounted) {
      setState(() {
        if (showLoader) {
          _loading = true;
        }
        _error = null;
      });
    }

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
      final preferredRaw = _applyingRaw ?? _selectedRaw;
      final hasPreferred = modes.any(
        (mode) => mode['raw']?.toString() == preferredRaw,
      );
      final selected = hasPreferred ? preferredRaw : 'native:auto';
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
        _error = null;
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
    if (_applying || raw == _selectedRaw) {
      return;
    }

    final strings = l10n(context);
    final previousRaw = _selectedRaw;
    setState(() {
      _selectedRaw = raw;
      _applying = true;
      _applyingRaw = raw;
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
      await _loadModes(showLoader: false);
      if (!mounted) {
        return;
      }
      unawaited(showHazukiPrompt(context, strings.displayModeApplied));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedRaw = previousRaw;
      });
      unawaited(
        showHazukiPrompt(
          context,
          strings.displayModeSetFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _applying = false;
          _applyingRaw = null;
        });
      }
    }
  }

  String _modeLabel(BuildContext context, Map<String, dynamic> mode) {
    return mode['label']?.toString() ??
        mode['raw']?.toString() ??
        l10n(context).displayModeUnknownMode;
  }

  Map<String, dynamic>? _findModeByRaw(String? raw) {
    if (raw == null) {
      return null;
    }
    for (final mode in _modes) {
      if (mode['raw']?.toString() == raw) {
        return mode;
      }
    }
    return null;
  }

  String _activeModeLabel(BuildContext context) {
    final active = _findModeByRaw(_activeRaw);
    if (active != null) {
      return _modeLabel(context, active);
    }
    return _activeRaw ?? l10n(context).displayModeUnknown;
  }

  String _selectedModeLabel(BuildContext context) {
    final selected = _findModeByRaw(_selectedRaw);
    if (selected != null) {
      return _modeLabel(context, selected);
    }
    return _selectedRaw;
  }

  bool _isAutoMode(Map<String, dynamic> mode) {
    return mode['raw']?.toString() == 'native:auto';
  }

  double _refreshRateOf(Map<String, dynamic> mode) {
    final raw = mode['refreshRate'];
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int _intField(Map<String, dynamic> mode, String key) {
    final raw = mode[key];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _formatRefreshRate(double value) {
    final rounded = value.roundToDouble();
    final text = (value - rounded).abs() < 0.05
        ? rounded.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text Hz';
  }

  String _compactRefreshRate(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String? _modeDetails(Map<String, dynamic> mode) {
    final parts = <String>[];
    final refreshRate = _refreshRateOf(mode);
    final width = _intField(mode, 'width');
    final height = _intField(mode, 'height');
    if (refreshRate > 0) {
      parts.add(_formatRefreshRate(refreshRate));
    }
    if (width > 0 && height > 0) {
      parts.add('$width × $height');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }

  Map<String, dynamic>? _highestRefreshMode() {
    final candidates = _modes.where((mode) => !_isAutoMode(mode)).toList();
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) {
      final rateCompare = _refreshRateOf(b).compareTo(_refreshRateOf(a));
      if (rateCompare != 0) {
        return rateCompare;
      }
      final aPixels = _intField(a, 'width') * _intField(a, 'height');
      final bPixels = _intField(b, 'width') * _intField(b, 'height');
      return bPixels.compareTo(aPixels);
    });
    return candidates.first;
  }

  Widget _buildSummaryTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highest = _highestRefreshMode();
    final highestRefreshLabel = highest == null
        ? null
        : _formatRefreshRate(_refreshRateOf(highest));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.98),
            colorScheme.secondaryContainer.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 24,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n(context).displayRefreshRateTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_applying)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: colorScheme.onPrimaryContainer,
                  ),
                )
              else if (highestRefreshLabel != null)
                _buildMetricChip(
                  context,
                  icon: Icons.flash_on_rounded,
                  label: highestRefreshLabel,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _activeModeLabel(context),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n(context).displayModeHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  context,
                  icon: Icons.radio_button_checked_rounded,
                  label: l10n(context).displayModeCurrentSubtitle,
                  value: _activeModeLabel(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryTile(
                  context,
                  icon: Icons.check_circle_outline_rounded,
                  label: l10n(context).displayModeSelectedSubtitle,
                  value: _selectedModeLabel(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool emphasized = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = emphasized
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final background = emphasized
        ? colorScheme.primaryContainer.withValues(alpha: 0.68)
        : colorScheme.surface.withValues(alpha: 0.86);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? colorScheme.primary.withValues(alpha: 0.24)
              : colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionIndicator(
    BuildContext context, {
    required bool selected,
    required bool active,
    required bool busy,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (busy) {
      return SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: colorScheme.primary,
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colorScheme.primary : Colors.transparent,
        border: Border.all(
          color: selected
              ? colorScheme.primary
              : active
              ? colorScheme.secondary
              : colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Icon(
        selected
            ? Icons.check_rounded
            : active
            ? Icons.radio_button_checked_rounded
            : Icons.circle_outlined,
        size: 16,
        color: selected
            ? colorScheme.onPrimary
            : active
            ? colorScheme.secondary
            : colorScheme.outline,
      ),
    );
  }

  Widget _buildModeLeading(
    BuildContext context,
    Map<String, dynamic> mode, {
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final refreshRate = _refreshRateOf(mode);
    final isAuto = _isAutoMode(mode);
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.86);
    final background = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.82)
        : colorScheme.surface.withValues(alpha: 0.88);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.26)
              : colorScheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAuto)
            Icon(Icons.auto_awesome_rounded, color: foreground, size: 22)
          else
            Text(
              _compactRefreshRate(refreshRate),
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: theme.textTheme.titleLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            isAuto ? _modeLabel(context, mode) : 'Hz',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(BuildContext context, Map<String, dynamic> mode) {
    final strings = l10n(context);
    final colorScheme = Theme.of(context).colorScheme;
    final raw = mode['raw']?.toString() ?? 'native:auto';
    final details = _modeDetails(mode);
    final refreshRate = _refreshRateOf(mode);
    final isSelected = raw == _selectedRaw;
    final isActive = raw == _activeRaw;
    final isPreferred = mode['isPreferred'] == true;
    final isBusy = _applying && _applyingRaw == raw;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _applying ? null : () => unawaited(_onSelect(raw)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.36)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : isActive
                  ? colorScheme.secondary
                  : colorScheme.outlineVariant.withValues(alpha: 0.72),
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeLeading(context, mode, selected: isSelected),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _modeLabel(context, mode),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildSelectionIndicator(
                          context,
                          selected: isSelected,
                          active: isActive,
                          busy: isBusy,
                        ),
                      ],
                    ),
                    if (details != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        details,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (refreshRate > 0)
                          _buildModeBadge(
                            context,
                            icon: Icons.bolt_rounded,
                            label: _formatRefreshRate(refreshRate),
                            emphasized: isSelected,
                          ),
                        if (isActive)
                          _buildModeBadge(
                            context,
                            icon: Icons.radio_button_checked_rounded,
                            label: strings.displayModeCurrentSubtitle,
                            emphasized: true,
                          ),
                        if (isPreferred)
                          _buildModeBadge(
                            context,
                            icon: Icons.check_circle_outline_rounded,
                            label: strings.displayModeSelectedSubtitle,
                            emphasized: isSelected,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(BuildContext context, {required double height}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return ListView(
      key: const ValueKey('display-mode-loading'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildPlaceholderCard(context, height: 220),
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        _buildPlaceholderCard(context, height: 118),
        const SizedBox(height: 12),
        _buildPlaceholderCard(context, height: 118),
        const SizedBox(height: 12),
        _buildPlaceholderCard(context, height: 118),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final strings = l10n(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListView(
      key: const ValueKey('display-mode-error'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.error.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.displayRefreshRateTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer.withValues(alpha: 0.88),
                  height: 1.45,
                ),
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _applying
                      ? null
                      : () {
                          unawaited(_loadModes());
                        },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(strings.commonRetry),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadModes(showLoader: false),
          child: CustomScrollView(
            key: const ValueKey('display-mode-content'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeroCard(context),
                    const SizedBox(height: 16),
                    ..._modes.map((mode) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildModeCard(context, mode),
                      );
                    }),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          ),
        ),
        if (_applying)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(l10n(context).displayRefreshRateTitle),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _loading
            ? _buildLoadingState(context)
            : _error != null
            ? _buildErrorState(context)
            : _buildContent(context),
      ),
    );
  }
}
