import 'package:flutter/material.dart';
import 'package:hilla_ride/core/config/legal_config.dart';
import 'package:hilla_ride/core/models/app_config_models.dart';
import 'package:hilla_ride/core/utils/legal_url_launcher.dart';

enum LegalContentKind { privacy, terms, about, contact }

class LegalContentScreen extends StatelessWidget {
  const LegalContentScreen({
    super.key,
    required this.kind,
    required this.config,
    required this.languageCode,
  });

  final LegalContentKind kind;
  final AppRemoteConfig config;
  final String languageCode;

  String get _title {
    final l10nKey = switch (kind) {
      LegalContentKind.privacy => 'privacy',
      LegalContentKind.terms => 'terms',
      LegalContentKind.about => 'about',
      LegalContentKind.contact => 'contact',
    };
    if (languageCode.startsWith('ar')) {
      return switch (l10nKey) {
        'privacy' => 'سياسة الخصوصية',
        'terms' => 'شروط الخدمة',
        'about' => 'حول التطبيق',
        'contact' => 'اتصل بنا',
        _ => '',
      };
    }
    return switch (l10nKey) {
      'privacy' => 'Privacy Policy',
      'terms' => 'Terms of Service',
      'about' => 'About',
      'contact' => 'Contact',
      _ => '',
    };
  }

  String get _inlineContent => switch (kind) {
        LegalContentKind.privacy => config.privacyFor(languageCode),
        LegalContentKind.terms => config.termsFor(languageCode),
        LegalContentKind.about => config.aboutFor(languageCode),
        LegalContentKind.contact => config.contactFor(languageCode),
      };

  String get _fallbackUrl => switch (kind) {
        LegalContentKind.privacy =>
          LegalConfig.privacyPolicyUrl(languageCode: languageCode),
        LegalContentKind.terms =>
          LegalConfig.termsOfServiceUrl(languageCode: languageCode),
        LegalContentKind.about => '',
        LegalContentKind.contact => '',
      };

  static Future<void> open({
    required BuildContext context,
    required LegalContentKind kind,
    required AppRemoteConfig config,
    required String languageCode,
  }) async {
    final inline = switch (kind) {
      LegalContentKind.privacy => config.privacyFor(languageCode),
      LegalContentKind.terms => config.termsFor(languageCode),
      LegalContentKind.about => config.aboutFor(languageCode),
      LegalContentKind.contact => config.contactFor(languageCode),
    };

    if (inline.trim().isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LegalContentScreen(
            kind: kind,
            config: config,
            languageCode: languageCode,
          ),
        ),
      );
      return;
    }

    final url = switch (kind) {
      LegalContentKind.privacy =>
        LegalConfig.privacyPolicyUrl(languageCode: languageCode),
      LegalContentKind.terms =>
        LegalConfig.termsOfServiceUrl(languageCode: languageCode),
      LegalContentKind.about => '',
      LegalContentKind.contact => '',
    };
    if (url.isNotEmpty) {
      await openLegalDocumentUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _inlineContent.trim();

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: content.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      languageCode.startsWith('ar')
                          ? 'لا يوجد محتوى متاح.'
                          : 'No content available.',
                      textAlign: TextAlign.center,
                    ),
                    if (_fallbackUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => openLegalDocumentUrl(_fallbackUrl),
                        child: Text(
                          languageCode.startsWith('ar')
                              ? 'فتح في المتصفح'
                              : 'Open in browser',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
    );
  }
}
