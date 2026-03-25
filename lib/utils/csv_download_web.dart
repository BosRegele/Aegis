// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a CSV file download in the browser.
Future<void> downloadCsvWeb(String csvContent, String filename) async {
  final bytes = csvContent.codeUnits;
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
