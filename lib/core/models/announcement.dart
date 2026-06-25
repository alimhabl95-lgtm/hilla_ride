class Announcement {
  const Announcement({
    required this.id,
    required this.audience,
    required this.title,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String audience;
  final String title;
  final String body;
  final DateTime? createdAt;

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    return Announcement(
      id: id,
      audience: data['audience'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
    );
  }
}
