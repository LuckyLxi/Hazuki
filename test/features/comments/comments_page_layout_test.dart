import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comments/view/comments_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';
import 'package:hazuki/widgets/source_image_gateway_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _parent = ComicCommentData(
  id: 'parent',
  avatar: '',
  userName: 'A reader with a long display name',
  time: 'Yesterday',
  content: 'A quiet moment worth reading twice.',
  replyCount: 1,
  score: 86,
);
const _reply = ComicCommentData(
  id: 'child',
  avatar: '',
  userName: 'Another reader',
  time: 'Today',
  content: 'The little details make the story.',
  score: 3,
);

const _backgroundBoundaryKey = ValueKey('comments-background-boundary');

void main() {
  late _Source source;
  late CommentFilterService filter;
  late CommentsInteractionState state;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    source = _Source();
    filter = CommentFilterService();
    state = CommentsInteractionState()
      ..initialLoading = false
      ..initialLoadSucceeded = true
      ..hasMore = false
      ..comments = [_parent];
  });

  tearDown(() => filter.dispose());

  Future<void> pumpComments(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double width = 390,
    double textScale = 1,
    bool showAppBar = true,
    bool isTabView = false,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: source,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme:
              theme ??
              ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: brightness,
                ),
              ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: _backgroundBoundaryKey,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  final page = CommentsPage(
                    sourceService: source,
                    filterService: filter,
                    comicId: 'comic',
                    sourceKey: 'source',
                    showAppBar: showAppBar,
                    interactionState: state,
                    isTabView: isTabView,
                  );
                  if (!isTabView) return page;
                  return NestedScrollView(
                    headerSliverBuilder: (context, _) => [
                      SliverOverlapAbsorber(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                          context,
                        ),
                        sliver: const SliverAppBar(
                          title: Text('Details'),
                          pinned: true,
                        ),
                      ),
                    ],
                    body: page,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final mode in ['page', 'embedded', 'tab']) {
      testWidgets('comments use the theme surface in $brightness $mode', (
        tester,
      ) async {
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: brightness,
        );
        // Use a contrasting host background to detect transparent list areas.
        final theme = ThemeData(brightness: brightness).copyWith(
          colorScheme: scheme,
          scaffoldBackgroundColor: const Color(0xffff00ff),
        );
        await pumpComments(
          tester,
          theme: theme,
          showAppBar: mode == 'page',
          isTabView: mode == 'tab',
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_backgroundBoundaryKey),
        );
        final background = await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            // Sample the list margin, clear of cards and the composer.
            final offset = (300 * image.width + 4) * 4;
            return Color.fromARGB(
              data.getUint8(offset + 3),
              data.getUint8(offset),
              data.getUint8(offset + 1),
              data.getUint8(offset + 2),
            );
          } finally {
            image.dispose();
          }
        });
        expect(background, scheme.surface);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('cards and expanded replies fit narrow $brightness screens', (
      tester,
    ) async {
      await pumpComments(
        tester,
        brightness: brightness,
        width: 320,
        textScale: 1.8,
        showAppBar: false,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Replies 1'));
      await tester.tap(find.text('Replies 1'));
      await tester.pumpAndSettle();
      expect(find.text('Another reader'), findsOneWidget);
      expect(state.expandedReplyIds, contains('parent'));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Hide replies'));
      await tester.tap(find.text('Hide replies'));
      await tester.pumpAndSettle();
      expect(find.text('Another reader'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('declared sort menu reloads comments on a narrow embedded page', (
    tester,
  ) async {
    source.sortOptions = const SourceCommentSortOptions(
      orders: {
        'new': {'zh': '最新', 'en': 'Newest'},
        'hot': {'zh': '热门', 'en': 'Popular'},
      },
      defaultOrder: 'new',
    );
    await pumpComments(tester, width: 320, textScale: 1.8, showAppBar: false);
    expect(find.text('Newest'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();
    expect(state.order, 'hot');
    expect(source.lastOrder, 'hot');
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Newest'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('undeclared sort menu stays hidden', (tester) async {
    await pumpComments(tester);
    expect(find.byIcon(Icons.swap_vert), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sort menu works inside the detail nested scroll view', (
    tester,
  ) async {
    source.sortOptions = const SourceCommentSortOptions(
      orders: {'new': 'Newest', 'hot': 'Popular'},
      defaultOrder: 'new',
    );
    await pumpComments(tester, isTabView: true);
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();
    expect(state.order, 'hot');
    expect(source.lastOrder, 'hot');
    expect(find.text('Popular'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty comments retain the sort control on a standalone page', (
    tester,
  ) async {
    source.sortOptions = const SourceCommentSortOptions(
      orders: {'new': 'Newest', 'hot': 'Popular'},
      defaultOrder: 'new',
    );
    state.comments = [];
    await pumpComments(tester);
    expect(find.text('Newest'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();
    expect(source.lastOrder, 'hot');
    expect(state.comments.single.id, _parent.id);
    expect(find.text(_parent.userName), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('card actions retain like locking and reply submission', (
    tester,
  ) async {
    await pumpComments(tester);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(state.comments.single.isLiked, isTrue);
    expect(state.comments.single.score, 87);
    expect(source.likeCount, 1);
    final pendingLike = tester.widget<TextButton>(
      find.ancestor(
        of: find.byIcon(Icons.favorite),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      ),
    );
    expect(pendingLike.onPressed, isNull);
    source.likeResult.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(state.replyToComment?.id, 'parent');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'A new reply');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(source.sentContent, 'A new reply');
    expect(source.sentReplyTo, 'parent');
    expect(source.sentSourceKey, 'source');
    expect(field.controller!.text, isEmpty);
    expect(state.replyToComment, isNull);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('read-only sources retain content without card actions', (
    tester,
  ) async {
    source.supportActions = false;
    await pumpComments(tester);
    expect(find.text(_parent.userName), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Replies 1'), findsOneWidget);
    expect(find.text('Reply'), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('comments without an id keep reply counts without actions', (
    tester,
  ) async {
    state.comments = [
      const ComicCommentData(
        avatar: '',
        userName: 'Reader',
        time: '',
        content: 'A comment without an identifier.',
        replyCount: 2,
      ),
    ];
    await pumpComments(tester);
    expect(find.text('Replies 2'), findsOneWidget);
    expect(find.text('Reply'), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Source extends Fake
    implements SourceCommentsGateway, SourceImageGateway {
  SourceCommentSortOptions sortOptions = const SourceCommentSortOptions();
  String? lastOrder;
  @override
  SourceCommentSortOptions commentSortOptionsForSource(String sourceKey) =>
      sortOptions;
  bool supportActions = true;
  int likeCount = 0;
  final likeResult = Completer<void>();
  String? sentContent;
  String? sentReplyTo;
  String? sentSourceKey;

  @override
  String? get activeSourceKey => 'source';
  @override
  bool isLoggedForSource(String sourceKey) => true;
  @override
  bool supportCommentSendForSource(String sourceKey) => supportActions;
  @override
  bool supportCommentLikeForSource(String sourceKey) => supportActions;
  @override
  bool supportCommentRepliesForSource(String sourceKey) => supportActions;

  @override
  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
    String order = '',
  }) async {
    lastOrder = order;
    return ComicCommentsPageResult(
      comments: replyTo == null ? [_parent] : [_reply],
      maxPage: 1,
    );
  }

  @override
  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
  }) {
    likeCount++;
    return likeResult.future;
  }

  @override
  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) async {
    sentContent = content;
    sentReplyTo = replyTo;
    sentSourceKey = sourceKey;
  }

  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {}
}
