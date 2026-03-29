import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/widgets.dart';

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
      final strings = AppLocalizations.of(context)!;
      setState(() {
        _loading = false;
        _error = strings.displayModeAndroidOnly;
      });
      return;
    }

    try {
      final modes = await fetchHazukiDisplayModes();
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
      final strings = AppLocalizations.of(context)!;
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

    final strings = AppLocalizations.of(context)!;
    final previousRaw = _selectedRaw;
    setState(() {
      _selectedRaw = raw;
      _applying = true;
      _applyingRaw = raw;
    });

    try {
      bool applied;
      if (raw == 'native:auto') {
        await applyHazukiAutoDisplayMode();
        applied = true;
      } else {
        applied = await applyHazukiDisplayModeRaw(raw);
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
        AppLocalizations.of(context)!.displayModeUnknownMode;
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
    return _activeRaw ?? AppLocalizations.of(context)!.displayModeUnknown;
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
    final width = _intField(mode, 'width');
    final height = _intField(mode, 'height');
    if (width > 0 && height > 0) {
      return '$width × $height';
    }
    final refreshRate = _refreshRateOf(mode);
    if (refreshRate > 0) {
      return _formatRefreshRate(refreshRate);
    }
    return null;
  }

  Widget _buildSectionCard(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppLocalizations.of(context)!;

    return _buildSectionCard(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.displayRefreshRateTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_applying)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.displayModeHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              label: strings.displayModeCurrentSubtitle,
              value: _activeModeLabel(context),
            ),
            _buildInfoRow(
              context,
              label: strings.displayModeSelectedSubtitle,
              value: _selectedModeLabel(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIcon(
    BuildContext context, {
    required bool selected,
    required bool active,
    required bool busy,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (busy) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary,
        ),
      );
    }
    return Icon(
      selected
          ? Icons.check_circle_rounded
          : active
          ? Icons.radio_button_checked_rounded
          : Icons.radio_button_unchecked_rounded,
      color: selected
          ? colorScheme.primary
          : active
          ? colorScheme.secondary
          : colorScheme.outline,
      size: 22,
    );
  }

  Widget _buildModeRateBox(
    BuildContext context,
    Map<String, dynamic> mode, {
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final refreshRate = _refreshRateOf(mode);
    final isAuto = _isAutoMode(mode);

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isAuto
                ? 'Auto'
                : (refreshRate > 0 ? _compactRefreshRate(refreshRate) : '--'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: selected ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isAuto ? '' : 'Hz',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(BuildContext context, Map<String, dynamic> mode) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final raw = mode['raw']?.toString() ?? 'native:auto';
    final details = _modeDetails(mode);
    final isSelected = raw == _selectedRaw;
    final isActive = raw == _activeRaw;
    final isPreferred = mode['isPreferred'] == true;
    final isBusy = _applying && _applyingRaw == raw;
    final subtitleParts = <String>[
      ?details,
      if (isActive) strings.displayModeCurrentSubtitle,
      if (isPreferred) strings.displayModeSelectedSubtitle,
    ];
    final subtitle = subtitleParts.join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _applying ? null : () => unawaited(_onSelect(raw)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.25)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : isActive
                  ? colorScheme.secondary.withValues(alpha: 0.7)
                  : colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            children: [
              _buildModeRateBox(context, mode, selected: isSelected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modeLabel(context, mode),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildSelectionIcon(
                context,
                selected: isSelected,
                active: isActive,
                busy: isBusy,
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return ListView(
      key: const ValueKey('display-mode-loading'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildPlaceholderCard(context, height: 140),
        const SizedBox(height: 16),
        _buildPlaceholderCard(context, height: 84),
        const SizedBox(height: 10),
        _buildPlaceholderCard(context, height: 84),
        const SizedBox(height: 10),
        _buildPlaceholderCard(context, height: 84),
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListView(
      key: const ValueKey('display-mode-error'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        _buildSectionCard(
          context,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, color: colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 16),
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
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Stack(
      children: [
        ListView(
          key: const ValueKey('display-mode-content'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildOverviewCard(context),
            const SizedBox(height: 16),
            ..._modes.map((mode) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildModeCard(context, mode),
              );
            }),
          ],
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
        title: Text(AppLocalizations.of(context)!.displayRefreshRateTitle),
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
