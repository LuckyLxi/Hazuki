part of '../main.dart';

int _hazukiPromptTicket = 0;
_HazukiPromptHandle? _activeHazukiPrompt;

class _HazukiPromptHandle {
  _HazukiPromptHandle({
    required this.entry,
    required this.completer,
    required this.dismiss,
  });

  final OverlayEntry entry;
  final Completer<void> completer;
  final void Function() dismiss;
}

Future<void> showHazukiPrompt(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration holdDuration = const Duration(seconds: 2),
}) async {
  final ticket = ++_hazukiPromptTicket;
  _activeHazukiPrompt?.dismiss();

  final overlay = Overlay.of(context, rootOverlay: true);

  var expanded = false;
  var textVisible = false;
  var removed = false;
  final completer = Completer<void>();

  late OverlayEntry entry;

  void markNeedsBuild() {
    if (!removed) {
      entry.markNeedsBuild();
    }
  }

  void removeEntry() {
    if (removed) {
      return;
    }
    removed = true;
    entry.remove();
    if (!completer.isCompleted) {
      completer.complete();
    }
    if (identical(_activeHazukiPrompt?.entry, entry)) {
      _activeHazukiPrompt = null;
    }
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final colorScheme = Theme.of(overlayContext).colorScheme;
      final backgroundColor = isError
          ? colorScheme.errorContainer
          : colorScheme.inverseSurface;
      final foregroundColor = isError
          ? colorScheme.onErrorContainer
          : colorScheme.onInverseSurface;

      return IgnorePointer(
        ignoring: true,
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 280),
                  curve: expanded
                      ? const Cubic(0.18, 0.84, 0.22, 1.0)
                      : const Cubic(0.4, 0.0, 0.2, 1.0),
                  offset: expanded ? Offset.zero : const Offset(0, 0.12),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 320),
                    curve: expanded
                        ? Curves.easeOutBack
                        : const Cubic(0.4, 0.0, 0.2, 1.0),
                    scale: expanded ? 1 : 0.9,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: expanded
                          ? Curves.easeOutBack
                          : const Cubic(0.4, 0.0, 0.2, 1.0),
                      width: expanded ? 248 : 44,
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tips_and_updates_rounded,
                            size: 18,
                            color: foregroundColor,
                          ),
                          ClipRect(
                            child: AnimatedAlign(
                              alignment: Alignment.centerLeft,
                              duration: const Duration(milliseconds: 240),
                              curve: textVisible
                                  ? const Cubic(0.18, 0.84, 0.22, 1.0)
                                  : const Cubic(0.4, 0.0, 0.2, 1.0),
                              widthFactor: textVisible ? 1 : 0,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 180),
                                  curve: textVisible
                                      ? Curves.easeOutCubic
                                      : Curves.easeInCubic,
                                  opacity: textVisible ? 1 : 0,
                                  child: Text(
                                    message,
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                    style: Theme.of(overlayContext)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: foregroundColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _activeHazukiPrompt = _HazukiPromptHandle(
    entry: entry,
    completer: completer,
    dismiss: removeEntry,
  );
  overlay.insert(entry);

  unawaited(() async {
    await Future<void>.delayed(const Duration(milliseconds: 70));
    if (removed || ticket != _hazukiPromptTicket) {
      removeEntry();
      return;
    }
    expanded = true;
    markNeedsBuild();

    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (removed || ticket != _hazukiPromptTicket) {
      removeEntry();
      return;
    }
    textVisible = true;
    markNeedsBuild();

    await Future<void>.delayed(holdDuration);
    if (removed || ticket != _hazukiPromptTicket) {
      removeEntry();
      return;
    }
    textVisible = false;
    markNeedsBuild();

    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (removed || ticket != _hazukiPromptTicket) {
      removeEntry();
      return;
    }
    expanded = false;
    markNeedsBuild();

    await Future<void>.delayed(const Duration(milliseconds: 320));
    removeEntry();
  }());

  await completer.future;
}
