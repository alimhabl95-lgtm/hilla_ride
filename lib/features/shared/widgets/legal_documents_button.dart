import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_config_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/shared/screens/legal_content_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class LegalDocumentsButton extends StatelessWidget {
  const LegalDocumentsButton({super.key});

  Future<void> _open(
    BuildContext context,
    LegalContentKind kind,
    AppRemoteConfig config,
    String lang,
  ) async {
    await LegalContentScreen.open(
      context: context,
      kind: kind,
      config: config,
      languageCode: lang,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = l10n.localeName.startsWith('ar') ? 'ar' : 'en';
    final configService = context.read<AppState>().appConfigService;

    return StreamBuilder<AppRemoteConfig>(
      stream: configService.watchConfig(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? AppRemoteConfig.defaults;

        return PopupMenuButton<_LegalAction>(
          tooltip: l10n.legalDocuments,
          icon: const Icon(Icons.policy_outlined),
          onSelected: (action) {
            final kind = switch (action) {
              _LegalAction.privacy => LegalContentKind.privacy,
              _LegalAction.terms => LegalContentKind.terms,
            };
            _open(context, kind, config, lang);
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
      },
    );
  }
}

enum _LegalAction { privacy, terms }
