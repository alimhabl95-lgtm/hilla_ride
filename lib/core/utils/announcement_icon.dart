import 'package:flutter/material.dart';

IconData announcementIconData(String? iconKey) {
  switch (iconKey) {
    case 'local_offer':
      return Icons.local_offer_outlined;
    case 'emoji_events':
      return Icons.emoji_events_outlined;
    case 'warning':
      return Icons.warning_amber_outlined;
    case 'build':
      return Icons.build_outlined;
    case 'info':
      return Icons.info_outline;
    case 'directions_car':
      return Icons.directions_car_outlined;
    case 'campaign':
    default:
      return Icons.campaign_outlined;
  }
}
