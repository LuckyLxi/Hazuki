part of '../history_page.dart';

extension _HistoryActions on _HistoryPageState {
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) {
      return;
    }

    final strings = AppLocalizations.of(context)!;
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return AlertDialog(
          title: Text(strings.historyDeleteSelectedTitle),
          content: Text(
            strings.historyDeleteSelectedContent(_selectedIds.length),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.commonConfirm),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInBack,
          ).value,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final newHistory = _history
        .where((e) => !_selectedIds.contains(e.id))
        .toList();
    await _saveHistory(newHistory);
    _updateHistoryState(() {
      _history = newHistory;
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _clearAll() async {
    final strings = AppLocalizations.of(context)!;
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return AlertDialog(
          title: Text(strings.historyClearAllTitle),
          content: Text(strings.historyClearAllContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.commonConfirm),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInBack,
          ).value,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await _saveHistory([]);
    _updateHistoryState(() {
      _history = [];
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _handleCopyComicId(ExploreComic comic) async {
    final strings = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: comic.id));
    if (!mounted) {
      return;
    }
    unawaited(showHazukiPrompt(context, strings.historyCopiedComicId));
  }

  Future<void> _handleDeleteHistoryItem(ExploreComic comic) async {
    final newHistory = _history.where((e) => e.id != comic.id).toList();
    await _saveHistory(newHistory);
    _updateHistoryState(() {
      _history = newHistory;
    });
  }
}
