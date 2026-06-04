import 'package:shopxy_customer/shared/format/json_parse.dart';

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
    this.fromUserAvatarUrl,
    this.shopId,
    this.shopName,
    this.shopSlug,
    this.shopLogoUrl,
    this.shopBannerUrl,
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

  /// Legacy denormalised snapshot — historically the inviter user's
  /// display name copied into a "shop name" column. Prefer [shopName]
  /// (the real Shop record's name) for rendering; this is kept as a
  /// fallback for older invites where the relation wasn't populated.
  final String? fromShopName;
  final String? displayName;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final String? fromUserName;
  final String? fromUserEmail;
  final String? fromUserAvatarUrl;

  /// Inviting shop's real identity (from the joined Shop record, not
  /// the legacy [fromShopName] string). When present these drive the
  /// invite card's branding — logo, banner, and tap-through slug.
  final int? shopId;
  final String? shopName;
  final String? shopSlug;
  final String? shopLogoUrl;
  final String? shopBannerUrl;

  bool get isPending => status == InviteStatus.pending;
  bool get isParty => linkType == InviteLinkType.party;

  /// Resolved shop name — prefers the joined record over the legacy
  /// snapshot. Returns null only when neither is set.
  String? get effectiveShopName => shopName ?? fromShopName;

  factory Invitation.fromJson(Map<String, dynamic> j) {
    final fromUser = j['fromUser'] as Map<String, dynamic>?;
    final shop = j['shop'] as Map<String, dynamic>?;
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
      expiresAt: parseDate(j['expiresAt']),
      respondedAt: parseDateOrNull(j['respondedAt']),
      createdAt: parseDate(j['createdAt']),
      fromUserName: fromUser?['name'] as String?,
      fromUserEmail: fromUser?['email'] as String?,
      fromUserAvatarUrl: fromUser?['avatarUrl'] as String?,
      shopId: shop?['id'] as int?,
      shopName: shop?['name'] as String?,
      shopSlug: shop?['slug'] as String?,
      shopLogoUrl: shop?['logoUrl'] as String?,
      shopBannerUrl: shop?['bannerUrl'] as String?,
    );
  }
}
