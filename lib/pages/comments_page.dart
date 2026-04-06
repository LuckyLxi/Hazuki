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
    this.isActiveInTabView = true,
  });

  final String comicId;
  final String? subId;
  final bool isTabView;
  final bool isActiveInTabView;

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
  final Set<String> _animatedCommentKeys = <String>{};

  List<ComicCommentData> _comments = const [];
  String? _errorMessage;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _sendingComment = false;
  int _currentPage = 1;
  int? _maxPage;
  ComicCommentData? _replyToComment;
  bool? _tabScrollAtTop;

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

  void _logCommentsEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    HazukiSourceService.instance.addApplicationLog(
      level: level,
      title: title,
      content: {
        'comicId': widget.comicId,
        'subId': widget.subId,
        'viewMode': widget.isTabView ? 'detail_tab' : 'page',
        'currentPage': _currentPage,
        'commentCount': _comments.length,
        'hasMore': _hasMore,
        if (content != null) ...content,
      },
      source: widget.isTabView ? 'comic_detail_comments' : 'comments',
    );
  }

  void _logTabTopState(ScrollMetrics metrics) {
    if (!widget.isTabView || metrics.axis != Axis.vertical) {
      return;
    }
    final atTop = metrics.pixels <= metrics.minScrollExtent + 0.5;
    if (_tabScrollAtTop == atTop) {
      return;
    }
    _tabScrollAtTop = atTop;
    _logCommentsEvent(
      atTop ? 'Comments tab reached top' : 'Comments tab left top',
      content: {
        'pixels': metrics.pixels.round(),
        'minScrollExtent': metrics.minScrollExtent.round(),
        'maxScrollExtent': metrics.maxScrollExtent.round(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.isTabView && !widget.isActiveInTabView) {
      return const SizedBox.expand();
    }
    final bodyList = _buildCommentsBodyList();

    if (widget.isTabView) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      return Column(
        children: [
          Expanded(child: bodyList),
          _buildBottomComposer(bottomInset: bottomInset),
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
