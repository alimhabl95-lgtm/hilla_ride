import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/chat_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/admin/widgets/admin_support_contact_card.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminSupportPanel extends StatelessWidget {
  const AdminSupportPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final supportService = context.read<AppState>().supportService;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminSupportContactCard(),
        Expanded(
          child: StreamBuilder<List<SupportMessage>>(
            stream: supportService.watchAllMessages(),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const [];
              if (messages.isEmpty) {
                return Center(child: Text(l10n.noSupportMessages));
              }

              final threads = <String, List<SupportMessage>>{};
              for (final message in messages) {
                threads.putIfAbsent(message.userId, () => []).add(message);
              }

              final entries = threads.entries.toList()
                ..sort((a, b) {
                  final aLatest = a.value.last.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bLatest = b.value.last.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bLatest.compareTo(aLatest);
                });

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final thread = entry.value;
                  final latest = thread.last;
                  final openCount = thread
                      .where((m) => m.status == 'open' && !m.isFromManager)
                      .length;
                  final date = latest.createdAt;
                  final dateLabel = date == null
                      ? ''
                      : DateFormat.yMMMd(l10n.localeName)
                          .add_jm()
                          .format(date);

                  return Card(
                    child: ListTile(
                      title: Text('${latest.userName} (${latest.userRole.name})'),
                      subtitle: Text(
                        '${latest.phone.isEmpty ? '' : '${latest.phone}\n'}${latest.message}${dateLabel.isEmpty ? '' : '\n$dateLabel'}',
                      ),
                      isThreeLine: true,
                      trailing: openCount > 0
                          ? CircleAvatar(
                              radius: 12,
                              child: Text('$openCount'),
                            )
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminSupportThreadScreen(
                            userId: entry.key,
                            userName: latest.userName,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class AdminSupportThreadScreen extends StatefulWidget {
  const AdminSupportThreadScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  State<AdminSupportThreadScreen> createState() =>
      _AdminSupportThreadScreenState();
}

class _AdminSupportThreadScreenState extends State<AdminSupportThreadScreen> {
  final _controller = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reply() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await context.read<AppState>().supportService.sendManagerReply(
            userId: widget.userId,
            userName: widget.userName,
            message: text,
          );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeThread() async {
    await context
        .read<AppState>()
        .supportService
        .closeThread(widget.userId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final supportService = context.read<AppState>().supportService;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        actions: [
          TextButton(
            onPressed: _closeThread,
            child: Text(l10n.closeThread),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<SupportMessage>>(
              stream: supportService.watchUserMessages(widget.userId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const [];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isManager = message.isFromManager;

                    return Align(
                      alignment: isManager
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                        ),
                        decoration: BoxDecoration(
                          color: isManager
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(message.message),
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
                      decoration: InputDecoration(
                        hintText: l10n.replyToUser,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _reply,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
