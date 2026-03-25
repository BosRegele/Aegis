// Conditional export: on web uses dart:html to trigger a browser download;
// on native platforms the function is a no-op stub.
export 'csv_download_stub.dart' if (dart.library.html) 'csv_download_web.dart';
