class Announcement {
  const Announcement({
    required this.id,
    required this.audience,
    required this.title,
    required this.body,
    this.createdAt,
    this.showAsBanner = false,
  });

  final String id;
  final String audience;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool showAsBanner;

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    final showAsBanner = data['showAsBanner'];
    return Announcement(
      id: id,
      audience: data['audience'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      showAsBanner: showAsBanner == true ||
          showAsBanner == 1 ||
          '$showAsBanner'.toLowerCase() == 'true',
    );
  }
}
