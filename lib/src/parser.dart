import 'dart:io';
import 'dart:isolate';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class HtmlUp {
  HtmlUp(this.htmlPath, {this.prefix = 'hu'});

  final String htmlPath;
  final String prefix;

  late final htmlFile = File(htmlPath);
  late final document = html_parser.parse(htmlFile.readAsStringSync());

  final _pattern = RegExp('{{(.*?)}}');

  String attr(String key) {
    return '$prefix-$key';
  }

  dynamic getValueFromJson(dynamic data, String path) {
    if (data == null) {
      return '';
    }

    if (path == r'$' || path.isEmpty) {
      return data;
    }

    final segments = path.split('.');
    final segment = segments.removeAt(0);

    if (data is Map) {
      return getValueFromJson(data[segment], segments.join('.'));
    } else {
      return getValueFromJson(data[int.parse(segment)], segments.join('.'));
    }
  }

  Future<bool> runCondition(String condition, Map<String, dynamic> data) async {
    final uri = Uri.dataFromString(
      'import "dart:isolate";void main(_, SendPort port) {port.send($condition);}',
      mimeType: 'application/dart',
    );

    final port = ReceivePort();
    await Isolate.spawnUri(uri, [], port.sendPort, errorsAreFatal: false);

    return await port.first;
  }

  Future<void> parseIf(
    Element search,
    Map<String, dynamic> data, {
    String? itemKey,
  }) async {
    final elements = search.querySelectorAll('[${attr('if')}]');

    for (final element in elements) {
      final conditions = element.attributes[attr('if')]!;

      element.attributes.remove(attr('if'));

      final js2DartCondition = conditions.trim().split('||').map((ands) {
        return ands.trim().split('&&').map((ors) {
          final segments = ors.trim().split(' ');

          if (segments.length == 3) {
            var target = segments.first;

            if (itemKey != null && target.startsWith(itemKey)) {
              target = target.substring(itemKey.length);

              if (target.startsWith('.')) {
                target = target.substring(1);
              }
            }

            var value = getValueFromJson(data, target);

            segments[0] =
                value == '' ? 'null' : "'${Uri.encodeFull('$value')}'";
          }

          return segments.join(' ');
        }).join(' && ');
      }).join(' || ');

      final result = await runCondition(js2DartCondition, data);

      if (!result) {
        element.remove();
      }
    }
  }

  Future<void> parseForEach(Element search, Map<String, dynamic> data) async {
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

        await parseIf(element, {...data, ...value}, itemKey: itemKey);

        buffer.write(element.outerHtml);
      }

      foreach.innerHtml = buffer.toString();
      foreach.attributes.removeWhere(
        (key, value) => key is String && key.startsWith(attr('')),
      );
    }
  }

  Future<String> parse(Map<String, dynamic> data) async {
    await parseForEach(document.documentElement!, data);
    await parseIf(document.documentElement!, data);

    return document.outerHtml.replaceAllMapped(
      _pattern,
      (match) => getValueFromJson(data, match.group(1)!.trim()),
    );
  }
}
