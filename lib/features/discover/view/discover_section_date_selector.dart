import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/hazuki_morph_dialog.dart';

class DiscoverSectionDateSelector extends StatefulWidget {
  const DiscoverSectionDateSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<CategoryRankingOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  State<DiscoverSectionDateSelector> createState() =>
      _DiscoverSectionDateSelectorState();
}

class _DiscoverSectionDateSelectorState
    extends State<DiscoverSectionDateSelector> {
  final GlobalKey _launcherKey = GlobalKey();
  bool _dialogOpen = false;
  int _landingVersion = 0;

  CategoryRankingOption get _selectedOption => widget.options.firstWhere(
    (option) => option.value == widget.selectedValue,
    orElse: () => widget.options.first,
  );

  @override
  Widget build(BuildContext context) {
    return HazukiMorphCapsule(
      visible: !_dialogOpen,
      landingVersion: _landingVersion,
      onPressed: _showDateDialog,
      icon: Icons.calendar_month_outlined,
      label: _selectedOption.label,
      decorationKey: _launcherKey,
      inkWellKey: const ValueKey<String>('weekly_date_launcher'),
      opacityKey: const ValueKey<String>('weekly_date_launcher_opacity'),
      landingKey: const ValueKey<String>('weekly_date_launcher_landing'),
    );
  }

  Future<void> _showDateDialog() async {
    if (_dialogOpen) return;
    final renderBox =
        _launcherKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final startRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    setState(() => _dialogOpen = true);
    await showHazukiMorphDialog<void>(
      context: context,
      builder: (dialogContext, animation) => _DateSelectorDialog(
        animation: animation,
        startRect: startRect,
        options: widget.options,
        selectedValue: widget.selectedValue,
        onSelected: widget.onSelected,
      ),
    );
    _restoreLauncher();
  }

  void _restoreLauncher() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _dialogOpen = false;
        _landingVersion++;
      });
    });
  }
}

class _DateSelectorDialog extends StatelessWidget {
  const _DateSelectorDialog({
    required this.animation,
    required this.startRect,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  static const double _dialogHeight = 420;

  final Animation<double> animation;
  final Rect startRect;
  final List<CategoryRankingOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dialogHeight = _dialogHeight.clamp(
          0.0,
          constraints.maxHeight - 32,
        );
        final endRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: startRect.width,
          height: dialogHeight,
        );
        return HazukiMorphDialogShell(
          animation: animation,
          startRect: startRect,
          endRect: endRect,
          launcherColor: colorScheme.primaryContainer,
          launcherBorderColor: colorScheme.primary.withValues(alpha: 0.24),
          launcherOverlay: HazukiMorphCapsuleContents(
            icon: Icons.calendar_month_outlined,
            label: _selectedLabel,
            color: colorScheme.onPrimaryContainer,
          ),
          beginRadius: HazukiMorphCapsule.cornerRadius,
          radiusGrowth: 16,
          beginElevation: 4,
          elevationGrowth: 4,
          animationKey: const ValueKey<String>('weekly_date_morph_animation'),
          shellKey: const ValueKey<String>('weekly_date_dialog'),
          child: _DateSelectorContents(
            height: dialogHeight,
            options: options,
            selectedValue: selectedValue,
            onSelected: onSelected,
          ),
        );
      },
    );
  }

  String get _selectedLabel => options
      .firstWhere(
        (option) => option.value == selectedValue,
        orElse: () => options.first,
      )
      .label;
}

class _DateSelectorContents extends StatefulWidget {
  const _DateSelectorContents({
    required this.height,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final double height;
  final List<CategoryRankingOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  State<_DateSelectorContents> createState() => _DateSelectorContentsState();
}

class _DateSelectorContentsState extends State<_DateSelectorContents> {
  static const double _itemExtent = 60;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final selectedIndex = widget.options.indexWhere(
      (option) => option.value == widget.selectedValue,
    );
    final estimatedViewportHeight = widget.height - 100;
    final centeredOffset =
        (selectedIndex * _itemExtent) -
        ((estimatedViewportHeight - _itemExtent) / 2);
    _scrollController = ScrollController(
      initialScrollOffset: centeredOffset.clamp(0, double.infinity),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.discoverSectionChooseDate,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemExtent: _itemExtent,
                itemCount: widget.options.length,
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final selected = option.value == widget.selectedValue;
                  return TweenAnimationBuilder<double>(
                    key: ValueKey<String>('weekly_date_${option.value}'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        key: selected
                            ? const ValueKey<String>(
                                'weekly_date_selected_target',
                              )
                            : null,
                        selected: selected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        selectedTileColor: theme.colorScheme.secondaryContainer,
                        leading: Icon(
                          selected
                              ? Icons.calendar_month
                              : Icons.calendar_month_outlined,
                        ),
                        title: Text(option.label),
                        trailing: selected
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () {
                          widget.onSelected(option.value);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
