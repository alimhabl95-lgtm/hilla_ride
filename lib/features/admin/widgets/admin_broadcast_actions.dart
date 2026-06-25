import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/broadcast_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminBroadcastActions extends StatelessWidget {
  const AdminBroadcastActions({super.key, required this.adminUser});

  final AppUser adminUser;

  @override
  Widget build(BuildContext context) {
    if (!adminUser.isOwnerManager) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.broadcastToDrivers,
          icon: const Icon(Icons.local_taxi_outlined),
          onPressed: () => _openComposeDialog(
            context,
            audience: 'drivers',
            title: l10n.broadcastToDrivers,
            icon: Icons.local_taxi,
          ),
        ),
        IconButton(
          tooltip: l10n.broadcastToCustomers,
          icon: const Icon(Icons.people_outline),
          onPressed: () => _openComposeDialog(
            context,
            audience: 'customers',
            title: l10n.broadcastToCustomers,
            icon: Icons.people,
          ),
        ),
      ],
    );
  }

  Future<void> _openComposeDialog(
    BuildContext context, {
    required String audience,
    required String title,
    required IconData icon,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final broadcastService = context.read<AppState>().broadcastService;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _BroadcastComposeDialog(
          audience: audience,
          title: title,
          icon: icon,
          l10n: l10n,
          messenger: messenger,
          broadcastService: broadcastService,
        );
      },
    );
  }
}

class _BroadcastComposeDialog extends StatefulWidget {
  const _BroadcastComposeDialog({
    required this.audience,
    required this.title,
    required this.icon,
    required this.l10n,
    required this.messenger,
    required this.broadcastService,
  });

  final String audience;
  final String title;
  final IconData icon;
  final AppLocalizations l10n;
  final ScaffoldMessengerState messenger;
  final BroadcastService broadcastService;

  @override
  State<_BroadcastComposeDialog> createState() => _BroadcastComposeDialogState();
}

class _BroadcastComposeDialogState extends State<_BroadcastComposeDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.l10n.announcementDefaultTitle,
    );
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final announcementTitle = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (announcementTitle.isEmpty || message.isEmpty) {
      widget.messenger.showSnackBar(
        SnackBar(content: Text(widget.l10n.announcementFieldsRequired)),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await widget.broadcastService.sendAnnouncement(
        audience: widget.audience,
        title: announcementTitle,
        message: message,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.usedFirestore
                ? widget.l10n.broadcastPublishedSummary(result.total)
                : widget.l10n.broadcastSentSummary(result.sent, result.total),
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.message?.isNotEmpty == true
                ? error.message!
                : widget.l10n.broadcastSendFailed,
          ),
        ),
      );
      setState(() => _sending = false);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.message?.isNotEmpty == true
                ? error.message!
                : widget.l10n.broadcastSendFailed,
          ),
        ),
      );
      setState(() => _sending = false);
    } catch (error) {
      if (!mounted) return;
      widget.messenger.showSnackBar(SnackBar(content: Text('$error')));
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return AlertDialog(
      icon: Icon(widget.icon),
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.audience == 'drivers'
                  ? l10n.broadcastDriversHint
                  : l10n.broadcastCustomersHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              enabled: !_sending,
              decoration: InputDecoration(
                labelText: l10n.announcementTitleLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              enabled: !_sending,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.announcementMessageLabel,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.sendAnnouncement),
        ),
      ],
    );
  }
}
