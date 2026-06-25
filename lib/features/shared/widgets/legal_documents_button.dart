import 'package:flutter/material.dart';
import 'package:hilla_ride/core/config/legal_config.dart';
import 'package:hilla_ride/core/utils/legal_url_launcher.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';

class LegalDocumentsButton extends StatelessWidget {
  const LegalDocumentsButton({super.key});

  Future<void> _open(BuildContext context, String url) =>
      openLegalDocumentUrl(url);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = l10n.localeName.startsWith('ar') ? 'ar' : 'en';

    return PopupMenuButton<_LegalAction>(
      tooltip: l10n.legalDocuments,
      icon: const Icon(Icons.policy_outlined),
      onSelected: (action) {
        final url = switch (action) {
          _LegalAction.privacy => LegalConfig.privacyPolicyUrl(languageCode: lang),
          _LegalAction.terms => LegalConfig.termsOfServiceUrl(languageCode: lang),
        };
        _open(context, url);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _LegalAction.privacy,
          child: ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: _LegalAction.terms,
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.termsOfService),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }
}

enum _LegalAction { privacy, terms }
