import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/widgets/hazuki_m3e_loading_indicator.dart';

class CommentsInitialLoadingView extends StatelessWidget {
  const CommentsInitialLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('comments-initial-loading'),
      padding: const EdgeInsets.only(top: 100),
      alignment: Alignment.topCenter,
      child: SizedBox.square(
        dimension: 64,
        child: HazukiM3ELoadingIndicator(
          semanticLabel: l10n(context).commonLoading,
        ),
      ),
    );
  }
}
