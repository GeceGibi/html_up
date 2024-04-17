part of 'parser.dart';

mixin class HtmlUpUtils {
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
}
