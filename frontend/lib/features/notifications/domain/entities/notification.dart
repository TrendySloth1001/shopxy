import 'package:shopxy/shared/format/json_parse.dart';

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

  final String id;
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
      kind == 'INVITE_CANCELLED' ||
      kind == 'INVITE_EXPIRED';

  String? get invitationId {
    final v = data['invitationId'];
    if (v == null) return null;
    return v.toString();
  }

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'].toString(),
        kind: j['kind'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        readAt: parseDateOrNull(j['readAt']),
        createdAt: parseDate(j['createdAt']),
      );
}
