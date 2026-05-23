import 'package:flutter/material.dart';

const double _historyBackToTopThreshold = 520;
const Duration _historyScrollToTopDuration = Duration(milliseconds: 360);

class HistoryPageScrollCoordinator extends ChangeNotifier {
  HistoryPageScrollCoordinator() {
    controller.addListener(_handleScroll);
  }

  final ScrollController controller = ScrollController();

  bool _showBackToTop = false;

  bool get showBackToTop => _showBackToTop;

  Future<void> scrollToTop() async {
    if (!controller.hasClients) {
      return;
    }
    await controller.animateTo(
      0,
      duration: _historyScrollToTopDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _handleScroll() {
    if (!controller.hasClients) {
      return;
    }
    final nextShowBackToTop =
        controller.position.pixels > _historyBackToTopThreshold;
    if (nextShowBackToTop == _showBackToTop) {
      return;
    }
    _showBackToTop = nextShowBackToTop;
    notifyListeners();
  }

  @override
  void dispose() {
    controller
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }
}
