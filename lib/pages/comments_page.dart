import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../l10n/l10n.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../widgets/widgets.dart';

part 'comments/comments_actions.dart';
part 'comments/comments_content_support.dart';
part 'comments/comments_widgets.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.comicId,
    this.subId,
    this.isTabView = false,
  });

  final String comicId;
  final String? subId;
  final bool isTabView;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage>
    with AutomaticKeepAliveClientMixin {
  static const _commentsLoadTimeout = Duration(seconds: 20);
  static const _pageSize = 16;
  static final RegExp _commentInlineImagePattern = RegExp(
    r'<img\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _commentBreakTagPattern = RegExp(
    r'<br\s*/?>',
    caseSensitive: false,
  );
  static final RegExp _commentBlockClosingTagPattern = RegExp(
    r'</(?:p|div|li)\s*>',
    caseSensitive: false,
  );
  static final RegExp _commentHtmlTagPattern = RegExp(r'<[^>]+>');
  static final RegExp _commentHtmlEntityPattern = RegExp(
    r'&(#x?[0-9A-Fa-f]+|[A-Za-z]+);',
  );

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();

  List<ComicCommentData> _comments = const [];
  String? _errorMessage;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _sendingComment = false;
  int _currentPage = 1;
  int? _maxPage;
  ComicCommentData? _replyToComment;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _updateCommentsState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bodyList = _buildCommentsBodyList();

    if (widget.isTabView) {
      return Column(
        children: [
          Expanded(child: bodyList),
          _buildBottomComposer(),
        ],
      );
    }

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(l10n(context).commentsTitle),
      ),
      resizeToAvoidBottomInset: true,
      body: bodyList,
      bottomNavigationBar: _buildBottomComposer(),
    );
  }
}
