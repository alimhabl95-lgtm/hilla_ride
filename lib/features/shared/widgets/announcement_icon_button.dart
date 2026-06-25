import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/shared/screens/announcements_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AnnouncementIconButton extends StatelessWidget {
  const AnnouncementIconButton({super.key, required this.role});

  final UserRole role;

  String get _audience =>
      role == UserRole.driver ? 'drivers' : 'customers';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<AppState>().announcementService;

    return StreamBuilder<List<Announcement>>(
      stream: service.watchAnnouncements(_audience),
      builder: (context, announcementSnapshot) {
        final items = announcementSnapshot.data ?? const [];

        return StreamBuilder<Set<String>>(
          stream: service.watchReadIds(),
          builder: (context, readSnapshot) {
            final readIds = readSnapshot.data ?? const {};
            final unread = service.unreadCount(items, readIds);

            return IconButton(
              tooltip: l10n.announcementsTitle,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AnnouncementsScreen(audience: _audience),
                  ),
                );
              },
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 9 ? '9+' : '$unread'),
                child: const Icon(Icons.campaign_outlined),
              ),
            );
          },
        );
      },
    );
  }
}
