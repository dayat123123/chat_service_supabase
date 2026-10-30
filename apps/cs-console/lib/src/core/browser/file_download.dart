import 'dart:js_interop';

import 'package:web/web.dart' as web;

void downloadCsv(String fileName, String content) {
  final blob = web.Blob(<JSAny>['﻿$content'.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
