class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;
  bool get isInvite =>
      kind == 'INVITE_RECEIVED' ||
      kind == 'INVITE_ACCEPTED' ||
      kind == 'INVITE_DECLINED' ||
      kind == 'INVITE_CANCELLED';

  int? get invitationId {
    final v = data['invitationId'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int,
        kind: j['kind'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
