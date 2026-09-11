/// Operational scroll state shared by navigation and diagnostic snapshots.
class ReaderScrollState {
  double? lastObservedListPixels;
  bool listUserScrollInProgress = false;
  String? activeProgrammaticListScrollReason;
  int? activeProgrammaticListTargetIndex;
  int? lastCompletedProgrammaticListTargetIndex;
  DateTime? lastCompletedProgrammaticListScrollAt;
  int? stabilizingProgrammaticListTargetIndex;
  DateTime? stabilizeProgrammaticListUntil;

  bool get hasActiveProgrammaticListStabilization {
    final target = stabilizingProgrammaticListTargetIndex;
    final until = stabilizeProgrammaticListUntil;
    return target != null && until != null && DateTime.now().isBefore(until);
  }

  void clearProgrammaticListStabilization() {
    stabilizingProgrammaticListTargetIndex = null;
    stabilizeProgrammaticListUntil = null;
  }

  void markProgrammaticListScrollCompleted(
    int target, {
    bool stabilize = false,
  }) {
    lastCompletedProgrammaticListTargetIndex = target;
    lastCompletedProgrammaticListScrollAt = DateTime.now();
    if (stabilize) {
      stabilizingProgrammaticListTargetIndex = target;
      stabilizeProgrammaticListUntil = lastCompletedProgrammaticListScrollAt!
          .add(const Duration(seconds: 3));
    }
  }
}
