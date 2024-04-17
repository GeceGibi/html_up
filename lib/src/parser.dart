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
  late final document = html_parser.parse(htmlFile.readAsStringSync());

  final _pattern = RegExp('{{(.*?)}}');

  String attr(String key) {
    return '$prefix-$key';
  }

  void parseIf(Element search, Map<String, dynamic> data, {String? itemKey}) {
    final elements = search.querySelectorAll('[${attr('if')}]');

    for (final element in elements) {
      final jsCondition = element.attributes[attr('if')]!;
      final parser = IfParser(jsCondition, data, itemKey: itemKey);

      element.attributes.remove(attr('if'));

      if (!parser.runCondition()) {
        element.remove();
      }
    }
  }

  void parseForEach(Element search, Map<String, dynamic> data) {
    for (final foreach in search.querySelectorAll('[${attr('foreach')}]')) {
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

              return getValueFromJson(value, location);
            }

            if (indexKey != null && valueLocation == indexKey) {
              return '$k';
            }

            return '';
          }),
        );

        parseIf(element, {...data, ...value}, itemKey: itemKey);

        buffer.write(element.outerHtml);
      }

      foreach.innerHtml = buffer.toString();
      foreach.attributes.removeWhere(
        (key, value) => key is String && key.startsWith(attr('')),
      );
    }
  }

  Future<String> parse(Map<String, dynamic> data) async {
    parseForEach(document.documentElement!, data);
    parseIf(document.documentElement!, data);

    return document.outerHtml.replaceAllMapped(
      _pattern,
      (match) => getValueFromJson(data, match.group(1)!.trim()),
    );
  }
}
