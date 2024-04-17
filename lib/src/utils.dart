part of 'compiler.dart';

mixin class HtmlUpUtils {
  String? getValueFromJson<T>(T data, String path, {bool returnNull = false}) {
    if (data == null) {
      return null;
    }

    if (path == r'$' || path.isEmpty) {
      return '$data';
    }

    final segments = path.split('.');
    final segment = segments.removeAt(0);

    return switch (data) {
      Map _ => getValueFromJson(data[segment], segments.join('.')),
      List _ => getValueFromJson(data[int.parse(segment)], segments.join('.')),
      _ => '',
    };
  }
}
