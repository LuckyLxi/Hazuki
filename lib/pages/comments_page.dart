import 'dart:async';
import 'dart:ui' as ui;

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
  final FocusNode _commentFocusNode = FocusNode();
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
    _commentFocusNode.addListener(_handleCommentFocusChanged);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentFocusNode
      ..removeListener(_handleCommentFocusChanged)
      ..dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _handleCommentFocusChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
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

    if (widget.isTabView) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final safeBottom = MediaQuery.paddingOf(context).bottom;
      const pillHoriz = 16.0;
      const pillMarginBottom = 6.0;
      const pillApproxHeight = 56.0;
      final listExtraBottom =
          pillApproxHeight + pillMarginBottom + safeBottom + bottomInset;
      return Stack(
        children: [
          _buildCommentsBodyList(extraBottomPadding: listExtraBottom),
          Positioned(
            left: pillHoriz,
            right: pillHoriz,
            bottom: safeBottom + pillMarginBottom + bottomInset,
            child: _buildBottomComposer(),
          ),
        ],
      );
    }

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(l10n(context).commentsTitle),
      ),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildCommentsBodyList(extraBottomPadding: 80),
          Positioned(
            left: 16,
            right: 16,
            bottom: safeBottom + 6,
            child: _buildBottomComposer(),
          ),
        ],
      ),
    );
  }
}
