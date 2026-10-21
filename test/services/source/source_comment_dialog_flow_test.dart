import '../../support/fake_source_task_control.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comments/state/comments_page_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ioAAAAASUVORK5CYII=',
);

class _Http implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return options.uri.path == '/captcha'
        ? ResponseBody.fromBytes(
            _png,
            200,
            headers: {
              'content-type': ['image/png'],
            },
          )
        : ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final outcome in ['submit', 'close', 'returnOnClose', 'leave']) {
    test('foreground comment captcha after HTTP: $outcome', () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'hazuki_comment_ui_',
      );
      final manager = SourcePluginManager(
        directory: () async => directory,
        legacyDirectories: [],
        download: (_) async => throw StateError('offline'),
      );
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      final filter = CommentFilterService();
      final ui = SourceUiService.instance;
      addTearDown(() async {
        ui.detach();
        assembly.dispose();
        filter.dispose();
        await directory.delete(recursive: true);
      });
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await manager.importPackage(
        utf8.encode('''
        Hazuki.registerSource({id:'comment_ui',name:'Comment UI',
          search:{load:async()=>({comics:[]})},
          comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]}),
            loadComments:async()=>({comments:[],maxPage:1}),
            sendComment:async(id,sub,text)=>{
              const response=await Hazuki.http.fetchBytes('GET','https://site.example/captcha');
              const dialog=await Hazuki.ui.openDialog({title:'Captcha',content:[
                {id:'captcha',type:'image',image:new Uint8Array(response.body)},
                {id:'answer',type:'input',label:'Code',required:true}],
                buttons:[{id:'send',text:'Send',validate:true}]});
              try {
                const event=await dialog.nextEvent();
                if(event.type==='closed' && ${outcome == 'returnOnClose'}) return;
                // Even a plugin ignoring cancellation cannot submit after leaving.
                const answer=event.type==='action'?event.values.answer:'';
                await Hazuki.http.sendRequest('POST','https://site.example/comment',{
                  'User-Agent':'Old plugin UA',
                  'Content-Type':'application/x-www-form-urlencoded',
                  'Referer':'https://site.example/','Origin':'https://site.example',
                  'X-Requested-With':'XMLHttpRequest'},
                  'video_id='+id+'&comment='+encodeURIComponent(text)+
                  '&originator=&status=false&invite_verification='+answer);
              } finally {await dialog.close();}
            }}});
      '''),
      );
      final handle = assembly.testing.handleFor('comment_ui');
      await handle.session.ensurePrefs();
      await handle.session.saveSourceData(
        'comment_ui',
        'login_session',
        'synthetic',
      );
      await handle.cookieStore.set('https://site.example/', [
        SourceCookie(
          name: 'AVS',
          value: 'synthetic',
          domain: 'site.example',
          path: '/',
          httpOnly: true,
          secure: true,
        ),
        SourceCookie(
          name: 'cf_clearance',
          value: 'synthetic',
          domain: 'site.example',
          path: '/',
          httpOnly: true,
          secure: true,
        ),
      ]);
      await handle.session.saveBrowserUserAgents({
        'https://site.example': 'Actual browser UA',
      });
      final http = _Http();
      handle.dio.httpClientAdapter = http;
      await assembly.ensureSourceInitialized('comment_ui');
      final controller = CommentsPageController(
        sourceService: assembly.gateways.commentsGateway,
        filterService: filter,
        comicId: 'comic',
        sourceKey: 'comment_ui',
        taskControl: FakeSourceTaskControl(),
      );
      var disposed = false;
      addTearDown(() {
        if (!disposed) controller.dispose();
      });
      final effects = <CommentsEffect>[];
      controller.effects.listen(effects.add);
      controller.setReplyTarget(
        const ComicCommentData(
          id: 'reply',
          avatar: '',
          userName: 'User',
          time: '',
          content: 'Original',
        ),
      );
      final shown = Completer<void>();
      ui.presenter = (dialog) async {
        expect(dialog.model.content.first.image, _png);
        expect(http.requests.single.uri.path, '/captcha');
        dialog.markShown();
        shown.complete();
        if (outcome == 'submit') {
          dialog.setValue('answer', '1234');
          dialog.action('send');
        } else if (outcome == 'close' || outcome == 'returnOnClose') {
          dialog.close('user');
        }
        await dialog.whenClosed;
      };
      final sending = controller.submitComment('hello world');
      await Future.any([
        shown.future,
        sending.then((_) {
          throw StateError(
            'Send ended before showing captcha: ${effects.map((e) => e.error).toList()}',
          );
        }),
      ]);
      if (outcome == 'leave') {
        controller.dispose();
        disposed = true;
      }
      await sending;
      // Let a cancelled worker observe its closed event and attempt its late HTTP.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final posts = http.requests.where((r) => r.method == 'POST');
      if (outcome == 'submit') {
        expect(posts, hasLength(1));
        expect(
          posts.single.data,
          'video_id=comic&comment=hello%20world&originator=&status=false&invite_verification=1234',
        );
        expect(posts.single.headers['User-Agent'], 'Actual browser UA');
        expect(posts.single.headers['cookie'], contains('AVS=synthetic'));
        expect(
          posts.single.headers['cookie'],
          contains('cf_clearance=synthetic'),
        );
        expect(
          effects.any((e) => e.type == CommentsEffectType.sendSucceeded),
          true,
        );
        expect(controller.state.replyToComment, isNull);
      } else {
        expect(posts, isEmpty);
        expect(
          effects.any((e) => e.type == CommentsEffectType.sendSucceeded),
          false,
        );
        expect(
          effects.any((e) => e.type == CommentsEffectType.sendFailed),
          false,
        );
        expect(controller.state.replyToComment?.id, 'reply');
      }
    });
  }
}
