part of 'parser.dart';

class IfParser with HtmlUpUtils {
  IfParser(this.jsCondition, this.data, {this.itemKey});
  final String jsCondition;
  final Map<String, dynamic> data;
  final String? itemKey;

  bool runCondition() {
    var ors = jsCondition.trim().split('||');

    return ors.map((ands) {
      final andsResult = ands.trim().split('&&').map((ors) {
        final segments = ors.trim().split(' ');

        if (segments.length == 3) {
          var target = segments.first;

          if (itemKey != null && target.startsWith(itemKey!)) {
            target = target.substring(itemKey!.length);

            if (target.startsWith('.')) {
              target = target.substring(1);
            }
          }

          var value = getValueFromJson(data, target);

          segments[0] = value == '' ? 'null' : "'${Uri.encodeFull('$value')}'";
        }

        return _runConditionSegments(segments);
      });

      return !andsResult.contains(false);
    }).contains(true);
  }

  dynamic _parseArgument(String arg) {
    final stringPattern = RegExp('^[\'"](.*)[\'"]\$');

    if (stringPattern.hasMatch(arg)) {
      return stringPattern.firstMatch(arg)!.group(1)!;
    }

    ///
    else if (arg == 'null') {
      return null;
    }

    try {
      return num.parse(arg);
    } catch (e) {
      // no-op
    }

    return arg;
  }

  bool _runConditionSegments(List<String> segments) {
    if (segments.length == 1) {
      return bool.tryParse(segments.first) ?? false;
    } else if (segments.length == 3) {
      final operator = segments[1];

      return switch (operator) {
        '==' => _parseArgument(segments.first) == _parseArgument(segments.last),
        '!=' => _parseArgument(segments.first) != _parseArgument(segments.last),
        '>' => _parseArgument(segments.first) > _parseArgument(segments.last),
        '>=' => _parseArgument(segments.first) >= _parseArgument(segments.last),
        '<' => _parseArgument(segments.first) < _parseArgument(segments.last),
        '<=' => _parseArgument(segments.first) <= _parseArgument(segments.last),
        _ => false,
      };
    }

    return false;
  }
}
