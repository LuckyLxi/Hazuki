import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Synchronous HTML operations for one JavaScript engine.
class SourceHtmlBridge {
  final Map<int, _HtmlDocument> _documents = {};

  void clear() => _documents.clear();

  dynamic handleOperation(Map<String, dynamic> request) {
    final function = request['function'];
    final key = _key(request['key']);
    if (function == 'parse') {
      final data = request['data'];
      if (data is! String) throw ArgumentError('html_invalid_input');
      _documents[key] = _HtmlDocument(html.parse(data));
      return null;
    }
    if (function == 'dispose') {
      _documents.remove(key);
      return null;
    }
    final isDocumentOperation =
        function == 'querySelector' ||
        function == 'querySelectorAll' ||
        function == 'getElementById';
    final documentKey = isDocumentOperation ? key : _key(request['doc']);
    final document = _documents[documentKey];
    if (document == null) throw StateError('html_document_disposed');
    if (isDocumentOperation) {
      return switch (function) {
        'querySelector' => document.register(
          document.dom.querySelector(request['query'] as String),
        ),
        'querySelectorAll' => document.registerAll(
          document.dom.querySelectorAll(request['query'] as String),
        ),
        'getElementById' => document.register(
          document.getElementById(request['id'] as String),
        ),
        _ => throw UnsupportedError('Unsupported HTML operation: $function'),
      };
    }
    final node = document.node(key);
    switch (function) {
      case 'node_text':
        return node.text ?? '';
      case 'node_type':
        return switch (node) {
          Text() => 'text',
          Element() => 'element',
          Comment() => 'comment',
          Document() => 'document',
          _ => 'unknown',
        };
      case 'node_toElement':
        return document.register(node is Element ? node : null);
    }
    if (node is! Element) throw StateError('html_node_not_element');
    return switch (function) {
      'getText' => node.text,
      'getAttributes' => {
        for (final entry in node.attributes.entries)
          entry.key.toString(): entry.value,
      },
      'dom_querySelector' => document.register(
        node.querySelector(request['query'] as String),
      ),
      'dom_querySelectorAll' => document.registerAll(
        node.querySelectorAll(request['query'] as String),
      ),
      'getChildren' => document.registerAll(node.children),
      'getNodes' => document.registerAll(node.nodes),
      'getInnerHTML' => node.innerHtml,
      'getParent' => document.register(node.parent),
      'getClassNames' => node.classes.toList(),
      'getId' => node.attributes['id'],
      'getLocalName' => node.localName,
      'getPreviousSibling' => document.register(node.previousElementSibling),
      'getNextSibling' => document.register(node.nextElementSibling),
      _ => throw UnsupportedError('Unsupported HTML operation: $function'),
    };
  }

  int _key(dynamic value) {
    if (value is num && value >= 0 && value == value.toInt()) {
      return value.toInt();
    }
    throw ArgumentError('html_invalid_key');
  }
}

class _HtmlDocument {
  _HtmlDocument(this.dom);

  final Document dom;
  final List<Node> _nodes = [];
  final Map<Node, int> _keys = Map.identity();

  Element? getElementById(String id) {
    if (id.isEmpty) return null;
    for (final element in dom.querySelectorAll('[id]')) {
      if (element.attributes['id'] == id) return element;
    }
    return null;
  }

  int? register(Node? node) {
    if (node == null) return null;
    return _keys.putIfAbsent(node, () {
      _nodes.add(node);
      return _nodes.length - 1;
    });
  }

  List<int> registerAll(Iterable<Node> nodes) => [
    for (final node in nodes) register(node)!,
  ];

  Node node(int key) {
    if (key >= _nodes.length) throw StateError('html_node_not_found');
    return _nodes[key];
  }
}
