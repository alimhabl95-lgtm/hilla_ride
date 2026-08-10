// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

void downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) {
  final bytes = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}

void openPrintableHtml({
  required String filename,
  required String htmlContent,
}) {
  final blob = html.Blob([htmlContent], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  html.Url.revokeObjectUrl(url);
}
