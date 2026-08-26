import 'package:shopxy/shared/format/json_parse.dart';

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

enum InviteLinkType { party, vendor, team }

InviteLinkType _typeFrom(String raw) {
  switch (raw) {
    case 'VENDOR':
      return InviteLinkType.vendor;
    case 'TEAM':
      return InviteLinkType.team;
    case 'PARTY':
    default:
      return InviteLinkType.party;
  }
}

class Invitation {
  const Invitation({
    required this.id,
    required this.fromUserId,
    required this.toEmail,
    required this.toUserId,
    required this.linkType,
    required this.partyId,
    required this.vendorId,
    this.teamRole,
    required this.status,
    required this.message,
    required this.fromShopName,
    required this.displayName,
    this.teamRoleName,
    this.teamPermissions = const [],
    required this.expiresAt,
    required this.respondedAt,
    required this.createdAt,
    this.fromUserName,
    this.fromUserEmail,
  });

  final String id;
  final String fromUserId;
  final String toEmail;
  final String? toUserId;
  final InviteLinkType linkType;
  final String? partyId;
  final String? vendorId;
  final String? teamRole;
  final String? teamRoleName;
  final List<String> teamPermissions;
  final InviteStatus status;
  final String? message;
  final String? fromShopName;
  final String? displayName;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final String? fromUserName;
  final String? fromUserEmail;

  bool get isAccepted => status == InviteStatus.accepted;
  bool get isParty => linkType == InviteLinkType.party;
  bool get isTeam => linkType == InviteLinkType.team;

  bool get isEffectivelyExpired =>
      status == InviteStatus.pending && DateTime.now().isAfter(expiresAt);

  InviteStatus get effectiveStatus =>
      isEffectivelyExpired ? InviteStatus.expired : status;

  bool get isPending => effectiveStatus == InviteStatus.pending;

  factory Invitation.fromJson(Map<String, dynamic> j) {
    final fromUser = j['fromUser'] as Map<String, dynamic>?;
    return Invitation(
      id: j['id'].toString(),
      fromUserId: j['fromUserId'].toString(),
      toEmail: j['toEmail'] as String,
      toUserId: j['toUserId']?.toString(),
      linkType: _typeFrom(j['linkType'] as String),
      partyId: j['partyId']?.toString(),
      vendorId: j['vendorId']?.toString(),
      teamRole: j['teamRole'] as String?,
      teamRoleName: j['teamRoleName'] as String?,
      teamPermissions:
          (j['teamPermissions'] as List?)?.cast<String>() ?? const [],
      status: _statusFrom(j['status'] as String),
      message: j['message'] as String?,
      fromShopName: j['fromShopName'] as String?,
      displayName: j['displayName'] as String?,
      expiresAt: parseDate(j['expiresAt']),
      respondedAt: parseDateOrNull(j['respondedAt']),
      createdAt: parseDate(j['createdAt']),
      fromUserName: fromUser?['name'] as String?,
      fromUserEmail: fromUser?['email'] as String?,
    );
  }
}
