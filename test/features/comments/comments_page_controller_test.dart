import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comments/state/comments_page_controller.dart';
import 'package:hazuki/features/comments/view/comments_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _Source source;
  late CommentFilterService filter;
  late CommentsPageController controller;
  late List<CommentsEffect> effects;

  CommentsPageController create({CommentsInteractionState? state}) {
    final next = CommentsPageController(
      sourceService: source,
      filterService: filter,
      comicId: 'comic',
      subId: 'sub',
      chapterId: 'chapter',
      sourceKey: 'source',
      state: state,
    );
    next.effects.listen(effects.add);
    return next;
  }

  Future<void> load(List<ComicCommentData> comments, {int? maxPage = 3}) async {
    final loading = controller.loadInitial();
    source.pages.last.complete(comments, maxPage: maxPage);
    await loading;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    source = _Source();
    filter = CommentFilterService();
    effects = [];
    controller = create();
  });

  tearDown(() {
    controller.dispose();
    filter.dispose();
  });

  test(
    'initial load retains source and chapter scope and supports retry',
    () async {
      final initial = controller.loadInitial();
      final request = source.pages.single;
      expect(request.comicId, 'comic');
      expect(request.subId, 'sub');
      expect(request.chapterId, 'chapter');
      expect(request.sourceKey, 'source');
      expect(request.page, 1);
      expect(request.pageSize, 16);
      final error = StateError('offline');
      request.result.completeError(error);
      await initial;
      expect(controller.state.loadError, same(error));
      expect(controller.state.initialLoading, isFalse);
      expect(controller.state.initialLoadSucceeded, isFalse);

      await load([_comment('a')]);
      expect(controller.state.loadError, isNull);
      expect(controller.state.initialLoadSucceeded, isTrue);
      expect(controller.state.supportCommentLike, isTrue);
      expect(controller.state.supportCommentReplies, isTrue);
    },
  );

  test('an older initial response cannot replace the latest refresh', () async {
    final first = controller.loadInitial();
    final second = controller.loadInitial();
    source.pages[1].complete([_comment('new')], maxPage: 1);
    await second;
    source.pages[0].complete([_comment('old')]);
    await first;
    expect(controller.state.comments.single.id, 'new');
    expect(controller.state.hasMore, isFalse);
  });

  test(
    'pagination deduplicates requests and stops on duplicate-only pages',
    () async {
      await load([_comment('a')]);
      final pending = controller.loadMore();
      await controller.loadMore();
      expect(source.pages.length, 2);
      source.pages.last.complete([_comment('a'), _comment('b')]);
      await pending;
      expect(controller.state.comments.map((c) => c.id), ['a', 'b']);
      expect(controller.state.currentPage, 2);
      final duplicatePage = controller.loadMore();
      source.pages.last.complete([_comment('b')], maxPage: 10);
      await duplicatePage;
      expect(controller.state.hasMore, isFalse);
      await controller.loadMore();
      expect(source.pages.length, 3);
    },
  );

  test(
    'stale pagination failure does not unlock a newer page request',
    () async {
      await load([_comment('a')]);
      final oldPage = controller.loadMore();
      final oldRequest = source.pages.last;
      await load([_comment('fresh')]);
      final newPage = controller.loadMore();
      oldRequest.result.completeError(StateError('old failure'));
      await oldPage;
      expect(controller.state.loadingMore, isTrue);
      await controller.loadMore();
      expect(source.pages.length, 4);
      source.pages.last.complete([_comment('next')]);
      await newPage;
      expect(controller.state.comments.map((c) => c.id), ['fresh', 'next']);
    },
  );

  test('a failed page can be retried without advancing the page', () async {
    await load([_comment('a')]);
    final failure = controller.loadMore();
    source.pages.last.result.completeError(StateError('offline'));
    await failure;
    expect(controller.state.currentPage, 1);
    expect(controller.state.loadingMore, isFalse);
    final retry = controller.loadMore();
    expect(source.pages.last.page, 2);
    source.pages.last.complete([_comment('b')]);
    await retry;
    expect(controller.state.currentPage, 2);
  });

  test('hidden comments trigger bounded automatic pagination', () async {
    await filter.save(userKeywords: ['blocked'], mode: CommentFilterMode.hide);
    await load(List.generate(16, (i) => _comment('blocked-$i')));
    expect(source.pages.last.page, 2);
    source.pages.last.complete(List.generate(16, (i) => _comment('clean-$i')));
    await pumpEventQueue();
    expect(controller.visibleComments(controller.state.comments).length, 16);
    expect(source.pages.length, 2);
    expect(controller.state.hideFilterLoadMoreQueued, isFalse);
  });

  test(
    'hidden-filter pagination stops on failure and retries on filter change',
    () async {
      await filter.save(
        userKeywords: ['blocked'],
        mode: CommentFilterMode.hide,
      );
      await load([_comment('blocked')]);
      source.pages.last.result.completeError(StateError('offline'));
      await pumpEventQueue();
      expect(source.pages.length, 2);
      expect(controller.state.hideFilterLoadMoreQueued, isFalse);
      await filter.save(
        userKeywords: ['blocked'],
        mode: CommentFilterMode.hide,
      );
      expect(source.pages.length, 3);
      source.pages.last.complete([_comment('clean')], maxPage: 2);
      await pumpEventQueue();
      expect(controller.state.currentPage, 2);
    },
  );

  test(
    'likes are optimistic, deduplicated, and rolled back in replies too',
    () async {
      final comment = _comment('a').copyWith(score: 4);
      await load([comment]);
      controller.state.replyComments['parent'] = [comment];
      final pending = controller.toggleCommentLike(comment);
      await controller.toggleCommentLike(comment);
      expect(source.likes.length, 1);
      expect(source.likes.single.sourceKey, 'source');
      expect(controller.state.comments.single.score, 5);
      expect(controller.state.replyComments['parent']!.single.isLiked, isTrue);
      source.likes.single.result.completeError(StateError('denied'));
      await pending;
      expect(controller.state.comments.single, same(comment));
      expect(controller.state.replyComments['parent']!.single, same(comment));
      expect(controller.state.likingCommentIds, isEmpty);
      expect(effects.last.type, CommentsEffectType.likeFailed);
    },
  );

  test('a failed old like cannot overwrite refreshed comment data', () async {
    final old = _comment('a');
    await load([old]);
    final like = controller.toggleCommentLike(old);
    final fresh = old.copyWith(content: 'fresh', score: 20);
    await load([fresh]);
    source.likes.single.result.completeError(StateError('late failure'));
    await like;
    expect(controller.state.comments.single, same(fresh));
  });

  test('replies retain chronological order and reuse loaded content', () async {
    await load([_comment('parent')]);
    final parent = controller.state.comments.single;
    final first = controller.toggleReplies(parent);
    expect(source.pages.last.replyTo, 'parent');
    final newer = _comment('new').copyWith(time: '2026-09-08T10:00:00Z');
    final older = _comment('old').copyWith(time: '2026-09-08T09:00:00Z');
    source.pages.last.complete([newer, older], maxPage: 2);
    await first;
    expect(controller.state.replyComments['parent'], [older, newer]);
    await controller.toggleReplies(parent);
    await controller.toggleReplies(parent);
    expect(source.pages.length, 2);
    final next = controller.loadMoreReplies('parent');
    expect(source.pages.last.page, 2);
    source.pages.last.complete([newer, _comment('undated')], maxPage: 2);
    await next;
    expect(controller.state.replyComments['parent']!.length, 3);
    expect(controller.state.replyHasMore['parent'], isFalse);
    expect(controller.state.loadingReplyIds, isEmpty);
  });

  test(
    'sending validates login, capability, and empty input before requests',
    () async {
      await controller.submitComment('   ');
      source.loggedIn = false;
      await controller.submitComment('text');
      expect(effects.last.type, CommentsEffectType.loginRequired);
      source.loggedIn = true;
      source.canSend = false;
      await controller.submitComment('text');
      expect(effects.last.type, CommentsEffectType.sendUnsupported);
      expect(source.sends, isEmpty);
    },
  );

  test(
    'sending retains reply scope and stays busy through the refresh',
    () async {
      await load([_comment('parent')]);
      controller.setReplyTarget(controller.state.comments.single);
      final sending = controller.submitComment('  reply  ');
      await controller.submitComment('duplicate');
      final request = source.sends.single;
      expect(request.content, 'reply');
      expect(request.replyTo, 'parent');
      expect(request.sourceKey, 'source');
      expect(request.chapterId, 'chapter');
      request.result.complete();
      await pumpEventQueue();
      expect(
        effects.map((e) => e.type),
        contains(CommentsEffectType.sendSucceeded),
      );
      expect(controller.state.replyToComment, isNull);
      expect(controller.state.sendingComment, isTrue);
      expect(source.pages.last.page, 1);
      source.pages.last.complete([_comment('new')]);
      await sending;
      expect(controller.state.sendingComment, isFalse);
      expect(controller.state.comments.single.id, 'new');
    },
  );

  test('send failure preserves reply target and permits retry', () async {
    final parent = _comment('parent');
    controller.setReplyTarget(parent);
    final sending = controller.submitComment('reply');
    source.sends.single.result.completeError(StateError('offline'));
    await sending;
    expect(controller.state.replyToComment, same(parent));
    expect(controller.state.sendingComment, isFalse);
    expect(effects.last.type, CommentsEffectType.sendFailed);
    expect(source.pages, isEmpty);
    expect(controller.canSubmitComment('retry'), isTrue);
  });

  test(
    'reopening keeps loaded content and ignores a disposed sender',
    () async {
      await load([_comment('cached')]);
      final shared = controller.state;
      final sending = controller.submitComment('text');
      controller.dispose();
      effects.clear();
      controller = create(state: shared)..initialize();
      expect(controller.state.comments.single.id, 'cached');
      expect(controller.state.sendingComment, isFalse);
      expect(source.pages.length, 1);
      source.sends.single.result.complete();
      await sending;
      expect(effects, isEmpty);
      expect(source.pages.length, 1);
    },
  );

  test(
    'a disposed initial request cannot overwrite a reopened surface',
    () async {
      final oldLoad = controller.loadInitial();
      final shared = controller.state;
      controller.dispose();
      controller = create(state: shared);
      final newLoad = controller.loadInitial();
      source.pages[1].complete([_comment('new')]);
      await newLoad;
      source.pages[0].complete([_comment('old')]);
      await oldLoad;
      expect(shared.comments.single.id, 'new');
      expect(shared.initialLoading, isFalse);
    },
  );
  test(
    'closing a refresh does not leave cached comments stuck loading',
    () async {
      await load([_comment('cached')]);
      final refreshing = controller.loadInitial();
      final shared = controller.state;
      controller.dispose();
      controller = create(state: shared)..initialize();
      expect(shared.initialLoading, isFalse);
      expect(shared.comments.single.id, 'cached');
      expect(source.pages.length, 2);
      source.pages.last.complete([_comment('late')]);
      await refreshing;
      expect(shared.comments.single.id, 'cached');
    },
  );

  testWidgets(
    'page renders controller load errors and retries through its button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommentsPage(
            sourceService: source,
            filterService: filter,
            comicId: 'comic',
          ),
        ),
      );
      expect(source.pages.length, 1);
      source.pages.single.result.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(CommentsPage));
      final strings = AppLocalizations.of(context)!;
      expect(
        find.text(strings.commentsLoadFailed('Bad state: offline')),
        findsOneWidget,
      );
      await tester.tap(find.text(strings.commonRetry));
      await tester.pump();
      expect(source.pages.length, 2);
      source.pages.last.complete([], maxPage: 1);
      await tester.pumpAndSettle();
      expect(
        find.text(strings.commentsLoadFailed('Bad state: offline')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

ComicCommentData _comment(String id) => ComicCommentData(
  id: id,
  avatar: '',
  userName: 'user',
  time: '',
  content: id,
);

class _PageRequest {
  _PageRequest({
    required this.comicId,
    this.subId,
    this.chapterId,
    required this.sourceKey,
    required this.page,
    required this.pageSize,
    this.replyTo,
  });
  final String comicId;
  final String? subId;
  final String? chapterId;
  final String sourceKey;
  final int page;
  final int pageSize;
  final String? replyTo;
  final result = Completer<ComicCommentsPageResult>();

  void complete(List<ComicCommentData> comments, {int? maxPage = 3}) {
    result.complete(
      ComicCommentsPageResult(comments: comments, maxPage: maxPage),
    );
  }
}

class _Source extends Fake implements SourceCommentsGateway {
  bool loggedIn = true;
  bool canSend = true;
  final pages = <_PageRequest>[];
  final likes = <({String sourceKey, Completer<void> result})>[];
  final sends =
      <
        ({
          String sourceKey,
          String? chapterId,
          String content,
          String? replyTo,
          Completer<void> result,
        })
      >[];

  @override
  bool get isLogged => loggedIn;
  @override
  bool isLoggedForSource(String sourceKey) => loggedIn;
  @override
  bool get supportCommentSend => canSend;
  @override
  bool supportCommentSendForSource(String sourceKey) => canSend;
  @override
  bool get supportCommentLike => true;
  @override
  bool supportCommentLikeForSource(String sourceKey) => true;
  @override
  bool supportCommentRepliesForSource(String sourceKey) => true;

  @override
  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) {
    final request = _PageRequest(
      comicId: comicId,
      subId: subId,
      chapterId: chapterId,
      sourceKey: sourceKey,
      page: page,
      pageSize: pageSize,
      replyTo: replyTo,
    );
    pages.add(request);
    return request.result.future;
  }

  @override
  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
  }) {
    final result = Completer<void>();
    likes.add((sourceKey: sourceKey, result: result));
    return result.future;
  }

  @override
  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) {
    final result = Completer<void>();
    sends.add((
      sourceKey: sourceKey,
      chapterId: chapterId,
      content: content,
      replyTo: replyTo,
      result: result,
    ));
    return result.future;
  }

  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {}
}
