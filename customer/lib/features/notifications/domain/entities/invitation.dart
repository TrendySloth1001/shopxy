enum InviteStatus { pending, accepted, declined, cancelled, expired }

InviteStatus _statusFrom(String raw) {
  switch (raw) {
    case 'ACCEPTED':
      return InviteStatus.accepted;
    case 'DECLINED':
      return InviteStatus.declined;
    case 'CANCELLED':
      return InviteStatus.cancelled;
    case 'EXPIRED':
      return InviteStatus.expired;
    case 'PENDING':
    default:
      return InviteStatus.pending;
  }
}

enum InviteLinkType { party, vendor }

InviteLinkType _typeFrom(String raw) =>
    raw == 'VENDOR' ? InviteLinkType.vendor : InviteLinkType.party;

class Invitation {
  const Invitation({
    required this.id,
    required this.fromUserId,
    required this.toEmail,
    required this.toUserId,
    required this.linkType,
    required this.partyId,
    required this.vendorId,
    required this.status,
    required this.message,
    required this.fromShopName,
    required this.displayName,
    required this.expiresAt,
    required this.respondedAt,
    required this.createdAt,
    this.fromUserName,
    this.fromUserEmail,
  });

  final int id;
  final int fromUserId;
  final String toEmail;
  final int? toUserId;
  final InviteLinkType linkType;
  final int? partyId;
  final int? vendorId;
  final InviteStatus status;
  final String? message;
  final String? fromShopName;
  final String? displayName;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final String? fromUserName;
  final String? fromUserEmail;

  bool get isPending => status == InviteStatus.pending;
  bool get isParty => linkType == InviteLinkType.party;

  factory Invitation.fromJson(Map<String, dynamic> j) {
    final fromUser = j['fromUser'] as Map<String, dynamic>?;
    return Invitation(
      id: j['id'] as int,
      fromUserId: j['fromUserId'] as int,
      toEmail: j['toEmail'] as String,
      toUserId: j['toUserId'] as int?,
      linkType: _typeFrom(j['linkType'] as String),
      partyId: j['partyId'] as int?,
      vendorId: j['vendorId'] as int?,
      status: _statusFrom(j['status'] as String),
      message: j['message'] as String?,
      fromShopName: j['fromShopName'] as String?,
      displayName: j['displayName'] as String?,
      expiresAt: DateTime.parse(j['expiresAt'] as String),
      respondedAt: j['respondedAt'] == null
          ? null
          : DateTime.parse(j['respondedAt'] as String),
      createdAt: DateTime.parse(j['createdAt'] as String),
      fromUserName: fromUser?['name'] as String?,
      fromUserEmail: fromUser?['email'] as String?,
    );
  }
}
