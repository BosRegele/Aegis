// Stub used on native platforms (Android, iOS, Windows, …).
// The function is never called in practice because callers guard it with kIsWeb.
Future<void> downloadCsvWeb(String csvContent, String filename) async {}
