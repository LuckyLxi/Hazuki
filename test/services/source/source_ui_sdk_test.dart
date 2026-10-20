import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'quick dialogs return values, validate input and propagate cancellation',
    () async {
      final service = SourceUiService.instance;
      final engine = SourceScriptEngine(pluginId: 'quick');
      addTearDown(engine.close);
      addTearDown(service.detach);
      engine.setContextMessageHandler(
        (raw, execution) => service.handle(
          Map<String, dynamic>.from(raw as Map),
          execution,
          engine.runtimeId,
          'Quick',
        ),
      );
      await engine.execute(await rootBundle.loadString('assets/init.js'));
      await engine.execute(
        await rootBundle.loadString('assets/hazuki_plugin_sdk.js'),
      );
      final dialogs = <SourceDialogSession>[];
      service.presenter = (dialog) async {
        dialogs.add(dialog);
        dialog.markShown();
        switch (dialog.model.title) {
          case 'Input':
            expect(dialog.model.content.last.data['obscure'], true);
            dialog.action('confirm');
            expect(dialog.fieldErrors, contains('value'));
            dialog.setValue('value', 'answer');
            dialog.action('confirm');
          case 'Cancel':
            dialog.action('cancel');
          case 'Close':
            dialog.close('user');
          case 'Background':
            dialog.close('background');
          default:
            dialog.action('confirm');
        }
        await dialog.whenClosed;
      };
      expect(
        await service.run(
          () => engine.evaluate('''(async () => [
      (await Hazuki.ui.alert({title:'Notice',message:{en_US:'Hello'}})) === undefined,
      await Hazuki.ui.confirm({title:'Confirm'}),
      await Hazuki.ui.confirm({title:'Cancel',cancelText:'No'}),
      await Hazuki.ui.prompt({title:'Input',label:'Value',obscure:true,required:true,maxLength:10}),
      await Hazuki.ui.prompt({title:'Cancel',label:'Value'})
    ])()'''),
        ),
        [true, true, false, 'answer', null],
      );
      for (final title in ['Close', 'Background']) {
        expect(
          await service.run(
            () => engine.evaluate('''(async () => {
        try {await Hazuki.ui.confirm({title:'$title'}); return 'unexpected';}
        catch(e) {return [e.name,e.code,e.reason];}
      })()'''),
          ),
          [
            'PluginDialogCancelledError',
            'plugin_ui_cancelled',
            title == 'Close' ? 'user' : 'background',
          ],
        );
      }
      expect(dialogs.every((d) => d.isClosed), true);
      await expectLater(
        engine.evaluate("Hazuki.ui.alert({title:'Denied'})"),
        throwsA(anything),
      );
      expect(dialogs, hasLength(7));
    },
  );
  test(
    'runtime initialization and content inherit foreground UI, background actions do not',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('hazuki_dialog_');
      final manager = SourcePluginManager(
        directory: () async => directory,
        legacyDirectories: [],
        download: (_) async => throw StateError('offline'),
      );
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(() async {
        SourceUiService.instance.detach();
        assembly.dispose();
        await directory.delete(recursive: true);
      });
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await manager.importPackage(
        utf8.encode('''
      async function ask(title) {
        if (!await Hazuki.ui.isAvailable()) return 'background';
        const d = await Hazuki.ui.openDialog({title,content:[
          {id:'answer',type:'input',label:'Answer'}],buttons:[{id:'ok',text:'OK'}]});
        try { const e=await d.nextEvent();
          if(e.type==='closed') throw new Hazuki.ui.PluginDialogCancelledError(e.reason);
          return e.values.answer;
        } finally {await d.close();}
      }
      Hazuki.registerSource({id:'ui_runtime',name:'UI runtime',
        init:async()=>Hazuki.storage.set('initialized',await ask('Init')),
        search:{load:async()=>({comics:[{id:'one',title:await ask('Search'),cover:''}]})},
        comic:{loadInfo:async()=>({title:'One',chapters:{}}),loadEp:async()=>({images:[]})},
        account:{loginMethods:[{id:'none',title:'Login',input:'none'}],
          login:async()=>({token:await ask('Login')})},
        presentation:{actions:[{id:'ask',title:'Ask'}]},actions:{ask:()=>ask('Action')}});
    '''),
      );
      final handle = assembly.testing.handleFor('ui_runtime');
      handle.cache.imageCacheDir = directory;
      final titles = <Object>[];
      SourceUiService.instance.presenter = (dialog) async {
        titles.add(dialog.model.title);
        dialog.markShown();
        dialog.setValue('answer', 'accepted');
        dialog.action('ok');
        await dialog.whenClosed;
      };
      final result = await SourceUiService.instance.run(
        () => assembly.gateways.search.searchComics(
          keyword: 'test',
          page: 1,
          sourceKey: 'ui_runtime',
        ),
      );
      expect(result.comics.single.title, 'accepted');
      expect(
        handle.facade.loadSourceData('ui_runtime', 'initialized'),
        'accepted',
      );
      expect(titles, ['Init', 'Search']);
      expect(await assembly.runPluginAction('ui_runtime', 'ask'), 'background');
      expect(titles, ['Init', 'Search']);

      final loginSteps = <Object>[];
      await (assembly.gateways.accountGateway
              as SourceInteractiveAccountGateway)
          .loginInteractive(
            account: '',
            password: '',
            method: 'none',
            cancellation: SourceLoginCancellation(),
            present: (request, cancellation) async {
              expect(request['type'], 'pluginDialog');
              final dialog = request['session'] as SourceDialogSession;
              loginSteps.add(dialog.model.title);
              dialog.markShown();
              dialog.setValue('answer', 'accepted');
              dialog.action('ok');
              await dialog.whenClosed;
              return true;
            },
          );
      expect(loginSteps, ['Init', 'Login']);
      expect(assembly.gateways.accountGateway.isLogged, true);

      await manager.importPackage(
        utf8.encode('''
        Hazuki.registerSource({id:'pending_ui',name:'Pending UI',
          init:async()=>{const d=await Hazuki.ui.openDialog({title:'Pending',content:[],
            buttons:[{id:'ok',text:'OK'}]});const e=await d.nextEvent();
            if(e.type==='closed') throw new Hazuki.ui.PluginDialogCancelledError(e.reason);},
          search:{load:async()=>({comics:[]})},
          comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});
      '''),
      );
      final pendingHandle = assembly.testing.handleFor('pending_ui');
      pendingHandle.cache.imageCacheDir = directory;
      final showing = Completer<SourceDialogSession>();
      SourceUiService.instance.presenter = (dialog) async {
        dialog.markShown();
        showing.complete(dialog);
        await dialog.whenClosed;
      };
      final pending = SourceUiService.instance.run(
        () => assembly.ensureSourceInitialized('pending_ui'),
      );
      final cancelled = expectLater(
        pending,
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('plugin_ui_cancelled'),
          ),
        ),
      );
      final pendingDialog = await showing.future;
      expect(pendingHandle.runtime.engine, isNull);
      pendingHandle.requestDispose();
      await cancelled;
      expect(pendingDialog.isClosed, true);
      await pendingHandle.whenDisposed.timeout(const Duration(seconds: 5));
    },
  );
  test(
    'real QuickJS round-trips form updates and cancellation with task ownership',
    () async {
      final service = SourceUiService.instance;
      final engine = SourceScriptEngine(pluginId: 'example');
      addTearDown(engine.close);
      addTearDown(service.detach);
      engine.setContextMessageHandler(
        (raw, execution) => service.handle(
          Map<String, dynamic>.from(raw as Map),
          execution,
          engine.runtimeId,
          'Example',
        ),
      );
      await engine.execute(await rootBundle.loadString('assets/init.js'));
      await engine.execute(
        await rootBundle.loadString('assets/hazuki_plugin_sdk.js'),
      );
      expect(await engine.evaluate('Hazuki.ui.isAvailable()'), false);
      final shown = Completer<SourceDialogSession>();
      service.presenter = (dialog) async {
        dialog.markShown();
        shown.complete(dialog);
        await dialog.whenClosed;
      };
      final result = service.run(
        () => engine.evaluate('''(async () => {
      if (!await Hazuki.ui.isAvailable()) throw new Error('not available');
      const d = await Hazuki.ui.openDialog({title:'Form',content:[
        {id:'value',type:'input',label:'Value'}],buttons:[{id:'submit',text:'Submit'}]});
      const first = await d.nextEvent();
      await d.update({title:'Confirm',values:{value:'updated'},fieldErrors:{value:{en_US:'Retry'}}});
      const second = await d.nextEvent();
      await d.close();
      return {first, second};
    })()'''),
      );
      final dialog = await shown.future;
      dialog.setValue('value', 'original');
      dialog.action('submit');
      while (dialog.model.title != 'Confirm') {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(dialog.values['value'], 'updated');
      expect(dialog.fieldErrors, {
        'value': {'en_US': 'Retry'},
      });
      dialog.close('user');
      expect(await result, {
        'first': {
          'type': 'action',
          'id': 'submit',
          'values': {'value': 'original'},
        },
        'second': {'type': 'closed', 'reason': 'user'},
      });
      expect(await engine.evaluate('Hazuki.ui.isAvailable()'), false);
    },
  );
}
