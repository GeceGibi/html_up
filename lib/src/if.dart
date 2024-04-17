part of 'compiler.dart';

class IfParser with HtmlUpUtils {
  IfParser(this.jsCondition, this.data, {this.itemKey});
  final String jsCondition;
  final Map<String, dynamic> data;
  final String? itemKey;

  Iterable<String> _clean(List<String> segments) {
    return segments.map((e) => e.trim().replaceAll(RegExp(r'\s\s+'), ' '));
  }

  bool runCondition() {
    final result = _clean(jsCondition.trim().split('||')).map((ands) {
      final andsResult = _clean(ands.split('&&')).map((ors) {
        final segments = ors.split(' ');

        if (segments.length == 3) {
          final parsedLeft = _parseArgument(segments.first);

          if (parsedLeft != segments.first) {
            segments[0] = parsedLeft.toString();
          }

          ///
          else {
            var target = segments.first;

            if (itemKey != null && target.startsWith(itemKey!)) {
              target = target.substring(itemKey!.length);

              if (target.startsWith('.')) {
                target = target.substring(1);
              }
            }

            var value = getValueFromJson(data, target, returnNull: true);

            segments[0] = value == null ? 'null' : '"$value"';
          }
        }

        return _runConditionSegments(segments);
      });

      return !andsResult.contains(false);
    }).contains(true);

    return result;
  }

  dynamic _parseArgument(String arg) {
    final stringPattern = RegExp('^[\'"](.*)[\'"]\$');
    final intPattern = RegExp(r'^[\d,.-]+$');

    if (arg == 'null') {
      return null;
    }

    /// String
    else if (stringPattern.hasMatch(arg)) {
      return stringPattern.firstMatch(arg)!.group(1)!;
    }

    /// num
    else if (intPattern.hasMatch(arg)) {
      return num.parse(arg);
    }

    ///
    else if (arg case 'true' || 'false') {
      try {
        return bool.parse(arg);
      } catch (e) {
        // no-op
      }
    }

    return arg;
  }

  bool _runConditionSegments(List<String> segments) {
    if (segments.length == 1) {
      return bool.tryParse(segments.first) ?? false;
    }

    ///
    else if (segments.length == 3) {
      ///
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
