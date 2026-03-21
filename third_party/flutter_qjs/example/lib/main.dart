/*
 * @Description: example
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:51
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:28:06
 */
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

import 'highlight.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_qjs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: AppBarTheme(elevation: 0, systemOverlayStyle: SystemUiOverlayStyle.light), colorScheme: ColorScheme(background: Colors.grey[300]),
      ),
      routes: {
        'home': (BuildContext context) => TestPage(),
      },
      initialRoute: 'home',
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String resp;
  IsolateQjs engine;

  final CodeInputController _controller = CodeInputController(
      text: 'import("hello").then(({default: greet}) => greet("world"));');

  Future<void> _ensureEngine() async {
    return;
    engine = IsolateQjs(
      moduleHandler: (String module) async {
        return await rootBundle.loadString(
            "js/${module.replaceFirst(new RegExp(r".js$"), "")}.js");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("JS engine test"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton(
                      child: Text("evaluate"),
                      onPressed: () async {
                        await _ensureEngine();
                        try {
                          resp = (await engine.evaluate(_controller.text ?? '',
                                  name: "<eval>"))
                              .toString();
                        } catch (e) {
                          resp = e.toString();
                        }
                        setState(() {});
                      }),
                  TextButton(
                      child: Text("reset engine"),
                      onPressed: () async {
                        await engine.close();
                        engine = null;
                      }),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.withOpacity(0.1),
              constraints: BoxConstraints(minHeight: 200),
              child: TextField(
                  autofocus: true,
                  controller: _controller,
                  decoration: null,
                  expands: true,
                  maxLines: null),
            ),
            SizedBox(height: 16),
            Text("result:"),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.withOpacity(0.05),
              constraints: BoxConstraints(minHeight: 100),
              child: Text(resp ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}
