import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, required this.audience});

  final String audience;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  Set<String> _readIds = const {};
  var _markedVisible = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReadIds());
  }

  Future<void> _loadReadIds() async {
    final read =
        await context.read<AppState>().announcementService.getReadIds();
    if (mounted) setState(() => _readIds = read);
  }

  Future<void> _markVisibleAnnouncements(List<Announcement> items) async {
    if (_markedVisible || items.isEmpty) return;
    _markedVisible = true;

    final service = context.read<AppState>().announcementService;
    await service.markAllRead(items.map((item) => item.id));
    if (!mounted) return;
    setState(() => _readIds = items.map((item) => item.id).toSet());
  }

  Future<void> _markRead(Announcement item) async {
    await context.read<AppState>().announcementService.markRead(item.id);
    if (mounted) {
      setState(() => _readIds = {..._readIds, item.id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<AppState>().announcementService;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.announcementsTitle)),
      body: StreamBuilder<List<Announcement>>(
        stream: service.watchAnnouncements(widget.audience),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const [];
          if (items.isNotEmpty) {
            unawaited(_markVisibleAnnouncements(items));
          }

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.announcementsEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final isUnread = !_readIds.contains(item.id);
              final timeLabel = item.createdAt == null
                  ? ''
                  : DateFormat.yMMMd(l10n.localeName)
                      .add_jm()
                      .format(item.createdAt!);

              return Card(
                color: isUnread
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.35)
                    : null,
                child: ListTile(
                  leading: Icon(
                    Icons.campaign_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(item.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (timeLabel.isNotEmpty) ...[
                        Text(
                          timeLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(item.body),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => _markRead(item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
