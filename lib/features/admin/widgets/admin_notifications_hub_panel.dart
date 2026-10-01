import 'package:flutter/material.dart';
import 'package:hilla_ride/features/admin/widgets/admin_driver_announcements_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_notifications_center_panel.dart';

class AdminNotificationsHubPanel extends StatelessWidget {
  const AdminNotificationsHubPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            tabs: [
              Tab(text: isAr ? 'إرسال إشعار' : 'Push notification'),
              Tab(text: isAr ? 'إعلانات السائق' : 'Driver announcements'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminNotificationsCenterPanel(),
                AdminDriverAnnouncementsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
