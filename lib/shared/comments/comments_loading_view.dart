import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import 'package:hazuki/l10n/l10n.dart';

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
        child: LoadingIndicatorM3E(semanticLabel: l10n(context).commonLoading),
      ),
    );
  }
}
