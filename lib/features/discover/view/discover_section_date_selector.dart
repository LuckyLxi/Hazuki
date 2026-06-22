import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';

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
    extends State<DiscoverSectionDateSelector>
    with SingleTickerProviderStateMixin {
  static const double _launcherHeight = 36;
  static const double _cornerRadius = 12;

  final GlobalKey _launcherKey = GlobalKey();
  late final AnimationController _landingController;
  late final Animation<double> _landingOffset;
  late final Animation<double> _landingScale;
  bool _dialogOpen = false;

  CategoryRankingOption get _selectedOption => widget.options.firstWhere(
    (option) => option.value == widget.selectedValue,
    orElse: () => widget.options.first,
  );

  @override
  void initState() {
    super.initState();
    _landingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    final landingCurve = CurvedAnimation(
      parent: _landingController,
      curve: Curves.easeOutCubic,
    );
    _landingOffset = Tween<double>(begin: -3, end: 0).animate(landingCurve);
    _landingScale = Tween<double>(begin: 0.995, end: 1).animate(landingCurve);
  }

  @override
  void dispose() {
    _landingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(_cornerRadius);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AnimatedBuilder(
          animation: _landingController,
          builder: (context, child) => Transform.translate(
            key: const ValueKey<String>('weekly_date_launcher_landing'),
            offset: Offset(0, _landingOffset.value),
            child: Transform.scale(scale: _landingScale.value, child: child),
          ),
          child: Opacity(
            key: const ValueKey<String>('weekly_date_launcher_opacity'),
            opacity: _dialogOpen ? 0 : 1,
            child: IgnorePointer(
              ignoring: _dialogOpen,
              child: DecoratedBox(
                key: _launcherKey,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: radius,
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: radius,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey<String>('weekly_date_launcher'),
                    onTap: _showDateDialog,
                    child: SizedBox(
                      height: _launcherHeight,
                      child: _DateLauncherContents(
                        label: _selectedOption.label,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDateDialog() async {
    if (_dialogOpen) return;
    final renderBox =
        _launcherKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final startRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    setState(() => _dialogOpen = true);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          _DialogLifecycle(
            onDisposed: _restoreLauncher,
            child: _DateSelectorDialog(
              animation: animation,
              startRect: startRect,
              options: widget.options,
              selectedValue: widget.selectedValue,
              onSelected: widget.onSelected,
            ),
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  void _restoreLauncher() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _dialogOpen = false);
      _landingController.forward(from: 0);
    });
  }
}

class _DialogLifecycle extends StatefulWidget {
  const _DialogLifecycle({required this.onDisposed, required this.child});

  final VoidCallback onDisposed;
  final Widget child;

  @override
  State<_DialogLifecycle> createState() => _DialogLifecycleState();
}

class _DialogLifecycleState extends State<_DialogLifecycle> {
  @override
  void dispose() {
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dialogHeight = _dialogHeight.clamp(
          0.0,
          constraints.maxHeight - 32,
        );
        final endRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: startRect.width,
          height: _DiscoverSectionDateSelectorState._launcherHeight,
        );
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final progress = animation.value;
            final moveProgress = const Interval(
              0,
              0.78,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final expandProgress = const Interval(
              0.08,
              1,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final movingRect = Rect.lerp(startRect, endRect, moveProgress)!;
            final rect = Rect.fromCenter(
              center: movingRect.center,
              width: startRect.width,
              height:
                  _DiscoverSectionDateSelectorState._launcherHeight +
                  ((dialogHeight -
                          _DiscoverSectionDateSelectorState._launcherHeight) *
                      expandProgress),
            );
            final contentOpacity = const Interval(
              0.42,
              0.78,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final launcherOpacity =
                1 - const Interval(0.12, 0.42).transform(progress);
            final shellColor = Color.lerp(
              colorScheme.primaryContainer,
              colorScheme.surfaceContainerHigh,
              expandProgress,
            )!;
            return Stack(
              key: const ValueKey<String>('weekly_date_morph_animation'),
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: Material(
                    key: const ValueKey<String>('weekly_date_dialog'),
                    color: shellColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        _DiscoverSectionDateSelectorState._cornerRadius +
                            (16 * expandProgress),
                      ),
                      side: BorderSide(
                        color: Color.lerp(
                          colorScheme.primary.withValues(alpha: 0.24),
                          Colors.transparent,
                          expandProgress,
                        )!,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    elevation: 4 + (4 * expandProgress),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: launcherOpacity,
                          child: _DateLauncherContents(
                            label: _selectedLabel,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Positioned.fill(
                          child: Opacity(
                            opacity: contentOpacity,
                            child: _DateSelectorContents(
                              height: dialogHeight,
                              options: options,
                              selectedValue: selectedValue,
                              onSelected: onSelected,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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

class _DateLauncherContents extends StatelessWidget {
  const _DateLauncherContents({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.calendar_month_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
