import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/chat_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/legal_url_launcher.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/features/shared/screens/legal_content_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  var _sending = false;
  SupportContactInfo? _contact;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    final contact =
        await context.read<AppState>().supportService.getContactInfo();
    if (mounted) setState(() => _contact = contact);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    if (url.startsWith('http')) {
      await openLegalDocumentUrl(url);
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openLegal(LegalContentKind kind) async {
    final l10n = AppLocalizations.of(context)!;
    final lang = l10n.localeName.startsWith('ar') ? 'ar' : 'en';
    final config = await context.read<AppState>().appConfigService.getConfig();
    if (!mounted) return;
    await LegalContentScreen.open(
      context: context,
      kind: kind,
      config: config,
      languageCode: lang,
    );
  }

  Future<void> _send(AppUser profile) async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await context.read<AppState>().supportService.sendUserMessage(
            userId: profile.uid,
            userRole: profile.role,
            userName: profile.name,
            phone: profile.phone,
            message: text,
          );
      _controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.supportSent)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = context.read<AppState>().authService;
    final supportService = context.read<AppState>().supportService;
    final contact = _contact ?? SupportContactInfo.defaults;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportTitle)),
      body: StreamBuilder<AppUser?>(
        stream: authService.watchCurrentProfile(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.contactManagement,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      AppSecondaryButton(
                        label: '${l10n.callSupport}: ${contact.phone}',
                        icon: Icons.phone,
                        onPressed: () => _launch('tel:${contact.phone}'),
                      ),
                      const SizedBox(height: 8),
                      AppSecondaryButton(
                        label: l10n.whatsappSupport,
                        icon: Icons.chat,
                        onPressed: () {
                          final digits =
                              contact.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
                          _launch('https://wa.me/$digits');
                        },
                      ),
                      const SizedBox(height: 8),
                      AppSecondaryButton(
                        label: '${l10n.emailSupport}: ${contact.email}',
                        icon: Icons.email_outlined,
                        onPressed: () => _launch('mailto:${contact.email}'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.legalDocuments,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      AppSecondaryButton(
                        label: l10n.privacyPolicy,
                        icon: Icons.privacy_tip_outlined,
                        onPressed: () => _openLegal(LegalContentKind.privacy),
                      ),
                      const SizedBox(height: 8),
                      AppSecondaryButton(
                        label: l10n.termsOfService,
                        icon: Icons.description_outlined,
                        onPressed: () => _openLegal(LegalContentKind.terms),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<SupportMessage>>(
                  stream: supportService.watchUserMessages(profile.uid),
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? const [];

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = !message.isFromManager;
                        final time = message.createdAt;
                        final timeLabel = time == null
                            ? ''
                            : DateFormat.yMMMd(l10n.localeName)
                                .add_jm()
                                .format(time);

                        return Align(
                          alignment: isMine
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                            ),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.isFromManager
                                      ? l10n.managementReply
                                      : profile.name,
                                  style:
                                      Theme.of(context).textTheme.labelSmall,
                                ),
                                Text(message.message),
                                if (timeLabel.isNotEmpty)
                                  Text(
                                    timeLabel,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: l10n.supportMessageHint,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _sending ? null : () => _send(profile),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
