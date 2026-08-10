/// No-op on non-web platforms.
void downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) {
  throw UnsupportedError('File download is only supported on web.');
}

void openPrintableHtml({
  required String filename,
  required String htmlContent,
}) {
  throw UnsupportedError('HTML export is only supported on web.');
}
