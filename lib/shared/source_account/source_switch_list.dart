import 'package:flutter/material.dart';

/// Keeps the current source visible and focused when a picker opens.
class SourceSwitchList extends StatefulWidget {
  const SourceSwitchList({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<SourceSwitchList> createState() => _SourceSwitchListState();
}

class _SourceSwitchListState extends State<SourceSwitchList> {
  final _currentKey = GlobalKey();
  final _currentFocus = FocusNode(debugLabel: 'current-source');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentContext = _currentKey.currentContext;
      if (currentContext == null) return;
      final currentBox = currentContext.findRenderObject() as RenderBox;
      final viewportHeight = Scrollable.of(
        currentContext,
      ).position.viewportDimension;
      Scrollable.ensureVisible(
        currentContext,
        alignment: currentBox.size.height > viewportHeight ? 0 : 0.5,
      );
      _currentFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _currentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    children: [
      // Picker rows may have different heights, so lay them out together to
      // reveal the current row accurately even when it starts off screen.
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            if (i == widget.currentIndex)
              Focus(
                key: _currentKey,
                focusNode: _currentFocus,
                descendantsAreFocusable: false,
                child: widget.children[i],
              )
            else
              widget.children[i],
        ],
      ),
    ],
  );
}
