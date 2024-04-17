import 'dart:io';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

part 'if.dart';
part 'utils.dart';

class HtmlUp with HtmlUpUtils {
  HtmlUp(this.htmlPath, {this.prefix = 'hu'});
  final String htmlPath;
  final String prefix;

  late final htmlFile = File(htmlPath);
  late var document = html_parser.parse(htmlFile.readAsStringSync());

  final _pattern = RegExp('{{(.*?)}}');

  String attr(String key) {
    return '$prefix-$key';
  }

  void compileIf(
    Map<String, dynamic> data, {
    String? itemKey,
    Element? element,
  }) {
    final elements = (element ?? document.documentElement!).querySelectorAll(
      '[${attr('if')}]',
    );

    for (final element in elements) {
      final jsCondition = element.attributes[attr('if')]!;
      final parser = IfParser(jsCondition, data, itemKey: itemKey);

      element.attributes.remove(attr('if'));

      if (!parser.runCondition()) {
        element.remove();
      }
    }
  }

  void compileForEach(Map<String, dynamic> data) {
    for (final foreach
        in document.documentElement!.querySelectorAll('[${attr('foreach')}]')) {
      final buffer = StringBuffer();

      final dataKey = foreach.attributes[attr('foreach')];
      final itemKey = foreach.attributes[attr('item')];
      final indexKey = foreach.attributes[attr('index')];

      if (!data.containsKey(dataKey) && data[dataKey] is! Iterable) {
        return;
      }

      if (itemKey == null || itemKey.isEmpty) {
        return;
      }

      for (var k = 0; k < data[dataKey].length; k++) {
        final value = data[dataKey][k];

        final element = Element.html(
          foreach.innerHtml.replaceAllMapped(_pattern, (match) {
            final valueLocation = match.group(1)!.trim();

            if (valueLocation.startsWith(itemKey)) {
              var location = valueLocation.replaceAll(itemKey, '');

              if (location.startsWith('.')) {
                location = location.substring(1);
              }

              return getValueFromJson(value, location) ?? '';
            }

            if (indexKey != null && valueLocation == indexKey) {
              return '$k';
            }

            return '';
          }),
        );

        compileIf({...data, ...value}, itemKey: itemKey, element: element);
        buffer.write(element.outerHtml);
      }

      foreach.innerHtml = buffer.toString();
      foreach.attributes.removeWhere(
        (key, value) => key is String && key.startsWith(attr('')),
      );
    }
  }

  void compileImports() {
    for (final import in document.getElementsByTagName(attr('import'))) {
      final source = import.attributes['source'];

      if (source == null || source.isEmpty) {
        continue;
      }

      try {
        final content = File(source).readAsStringSync();
        import.replaceWith(Element.html(content));
      } catch (e) {
        print(e);
        continue;
      }
    }
  }

  void compileCommons(Map<String, dynamic> data, {bool preCompile = false}) {
    document = Document.html(document.outerHtml.replaceAllMapped(
      _pattern,
      (match) {
        final value = getValueFromJson(data, match.group(1)!.trim());

        if (preCompile && value == null) {
          return match.group(0)!;
        }

        return value ?? '';
      },
    ));
  }

  String compile(Map<String, dynamic> data) {
    compileCommons(data, preCompile: true);
    compileImports();
    compileForEach(data);
    compileIf(data);
    compileCommons(data);

    return document.outerHtml
        .replaceAll(RegExp('<!--.*?-->', dotAll: true), '');
  }
}
