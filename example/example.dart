import 'dart:io';

import 'package:html_up/html_up.dart';

void main(List<String> args) {
  final htmlUp = HtmlUp('./assets/home.html', prefix: 'x');

  final compiled = htmlUp.compile({
    'lang': Platform.localeName,
    'scripts': List.generate(10, (index) => 'script.$index.js'),
    'page': {
      'title': 'Working !',
      'header_source': './assets/header.html',
    },
    'pool': [
      1,
      {'name': 'Hi'},
      5,
    ],
    'items': [
      {'title': 'item one', 'image': ''},
      {'title': 'item one', 'image': null},
      {
        'title': 'item one',
        'image': 'https://th.wallhaven.cc/lg/3l/3lepy9.jpg',
      },
    ],
  });

  File('./build/home.html')
    ..createSync(recursive: true)
    ..writeAsStringSync(compiled);
}
