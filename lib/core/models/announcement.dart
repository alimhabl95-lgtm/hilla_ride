class Announcement {
  const Announcement({
    required this.id,
    required this.audience,
    required this.title,
    required this.body,
    this.createdAt,
    this.showAsBanner = false,
    this.showOnDriverDashboard = false,
    this.isActive = true,
    this.startsAt,
    this.expiresAt,
    this.imageUrl,
    this.iconKey,
  });

  final String id;
  final String audience;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool showAsBanner;
  final bool showOnDriverDashboard;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final String? imageUrl;
  final String? iconKey;

  bool isLiveAt(DateTime now) {
    if (!isActive) return false;
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (expiresAt != null && now.isAfter(expiresAt!)) return false;
    return title.trim().isNotEmpty;
  }

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    final showAsBanner = data['showAsBanner'];
    final showOnDriverDashboard = data['showOnDriverDashboard'];
    final isActiveRaw = data['isActive'];
    return Announcement(
      id: id,
      audience: data['audience'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      showAsBanner: showAsBanner == true ||
          showAsBanner == 1 ||
          '$showAsBanner'.toLowerCase() == 'true',
      showOnDriverDashboard: showOnDriverDashboard == true ||
          showOnDriverDashboard == 1 ||
          '$showOnDriverDashboard'.toLowerCase() == 'true',
      isActive: isActiveRaw == null ||
          isActiveRaw == true ||
          isActiveRaw == 1 ||
          '$isActiveRaw'.toLowerCase() == 'true',
      startsAt: (data['startsAt'] as dynamic)?.toDate() as DateTime?,
      expiresAt: (data['expiresAt'] as dynamic)?.toDate() as DateTime?,
      imageUrl: data['imageUrl'] as String?,
      iconKey: data['iconKey'] as String?,
    );
  }
}
