import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Triggers a CSV file download in the browser.
Future<void> downloadCsvWeb(String csvContent, String filename) async {
  final blob = web.Blob(
    [csvContent.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
}
