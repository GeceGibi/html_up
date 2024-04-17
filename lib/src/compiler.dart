import 'dart:convert';

import 'dart:io';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;

part 'if.dart';
part 'utils.dart';

typedef CompilerData = Map<String, dynamic>;

class HtmlUp with HtmlUpUtils {
  HtmlUp(this.htmlPath, {this.prefix = 'hu', this.encoding = utf8})
      : fileBytes = File(htmlPath).readAsBytesSync();

  final String htmlPath;
  final String prefix;
  final Encoding encoding;

  final List<int> fileBytes;

  ///
  var document = Document();

  String attr(String key) {
    return '$prefix-$key';
  }

  void compileIf(
    CompilerData data, {
    String? itemKey,
    Element? element,
    Map<String, dynamic> localData = const {},
  }) {
    final elements = (element ?? document).querySelectorAll(
      '[${attr('if')}]',
    );

    for (final element in elements) {
      final jsCondition = element.attributes[attr('if')]!;
      final parser = IfParser(
        jsCondition,
        {...data, ...localData},
        itemKey: itemKey,
      );

      element.attributes.remove(attr('if'));

      if (!parser.runCondition()) {
        element.remove();
      }
    }
  }

  void compileForEachAttributes(CompilerData data) {
    for (final foreach in document.querySelectorAll('[${attr('foreach')}]')) {
      final dataKey = foreach.attributes[attr('foreach')];
      final itemKey = foreach.attributes[attr('item')];
      final indexKey = foreach.attributes[attr('index')];
      final isClone = bool.parse(foreach.attributes[attr('clone')] ?? 'false');

      final output = <Element>[];

      if (!data.containsKey(dataKey) && data[dataKey] is! Iterable) {
        return;
      }

      if (itemKey == null || itemKey.isEmpty) {
        return;
      }

      for (var k = 0; k < data[dataKey].length; k++) {
        final value = data[dataKey][k];

        final element = Element.html(
          (isClone ? foreach.outerHtml : foreach.innerHtml)
              .replaceAllMapped(_pattern, (match) {
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

        if (isClone) {
          element.attributes.removeWhere(
            (key, value) => key is String && key.startsWith(attr('')),
          );
        }

        compileIf(
          data,
          itemKey: itemKey,
          element: element,
          localData: value is CompilerData ? value : {},
        );

        output.add(element);
      }

      if (isClone) {
        try {
          final tempIndex = foreach.parent!.nodes.indexOf(foreach);

          for (var i = 0; i < output.length; i++) {
            foreach.parent!.nodes.insert(
              tempIndex + (i + 1),
              output[i],
            );
          }

          foreach.remove();
        } catch (e) {}
      }

      ///
      else {
        foreach.innerHtml = output.map((e) => e.outerHtml).join();
        foreach.attributes.removeWhere(
          (key, value) => key is String && key.startsWith(attr('')),
        );
      }
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

  void compileCommons(CompilerData data, {bool preCompile = false}) {
    document = Document.html(
      document.outerHtml.replaceAllMapped(
        _pattern,
        (match) {
          final value = getValueFromJson(data, match.group(1)!.trim());

          if (preCompile && value == null) {
            return match.group(0)!;
          }

          return value ?? '';
        },
      ),
    );
  }

  String compile(CompilerData data) {
    final htmlParser = parser.HtmlParser(
      encoding.decode(fileBytes),
      encoding: encoding.name,
      parseMeta: false,
    );

    final parsed = htmlParser.parse();

    if (parsed.documentElement == null) {
      return '';
    }

    document = parsed;

    compileCommons(data, preCompile: true);
    compileImports();

    /// Foreach
    compileForEachAttributes(data);
    // compileForEachElements(data);

    compileIf(data);
    compileCommons(data);

    return document.outerHtml.replaceAll(
      RegExp('<!--.*?-->', dotAll: true),
      '',
    );
  }
}
