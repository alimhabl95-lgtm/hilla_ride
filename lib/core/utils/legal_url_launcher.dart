import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openLegalDocumentUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await canLaunchUrl(uri)) return;

  if (kIsWeb) {
    await launchUrl(uri, webOnlyWindowName: '_blank');
    return;
  }

  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
