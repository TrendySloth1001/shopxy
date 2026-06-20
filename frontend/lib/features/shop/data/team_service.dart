import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';

/// One member of the shop's team. `userId` is the user account id (used
/// for permission edits / remove). `roleName` is the human label.
class TeamMember {
  const TeamMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.isOwner,
    this.roleName,
    this.avatarUrl,
    this.permissions = const [],
  });

  final int userId;
  final String name;
  final String email;
  final String role; // OWNER | STAFF (+ legacy MANAGER/STOCKIST/CASHIER)
  final String? roleName;
  final bool isOwner;
  final String? avatarUrl;
  final List<String> permissions;

  /// What to show on the role badge.
  String get label => isOwner ? 'Owner' : (roleName ?? teamRoleLabel(role));

  factory TeamMember.fromJson(Map<String, dynamic> j) {
    final user = (j['user'] as Map<String, dynamic>?) ?? const {};
    return TeamMember(
      userId: user['id'] as int,
      name: (user['name'] as String?) ?? '',
      email: (user['email'] as String?) ?? '',
      role: j['role'] as String,
      roleName: j['roleName'] as String?,
      isOwner: (j['isOwner'] as bool?) ?? (j['role'] == 'OWNER'),
      avatarUrl: (user['avatarUrl'] as String?)?.trim().isEmpty == false
          ? (user['avatarUrl'] as String).trim()
          : null,
      permissions: (j['permissions'] as List?)?.cast<String>() ?? const [],
    );
  }
}

/// A pending team invitation (invited, not yet accepted).
class TeamInvite {
  const TeamInvite({
    required this.id,
    required this.email,
    required this.roleName,
    this.permissions = const [],
    this.expiresAt,
  });

  final int id;
  final String email;
  final String roleName;
  final List<String> permissions;
  final DateTime? expiresAt;

  factory TeamInvite.fromJson(Map<String, dynamic> j) => TeamInvite(
        id: j['id'] as int,
        email: (j['toEmail'] as String?) ?? '',
        roleName: (j['teamRoleName'] as String?) ?? 'Staff',
        permissions: (j['teamPermissions'] as List?)?.cast<String>() ?? const [],
        expiresAt: j['expiresAt'] != null
            ? DateTime.tryParse(j['expiresAt'] as String)
            : null,
      );
}

/// An owner-defined role: a named permission template.
class TeamRole {
  const TeamRole({
    required this.id,
    required this.name,
    required this.permissions,
    required this.builtin,
  });

  final int id;
  final String name;
  final List<String> permissions;
  final bool builtin;

  factory TeamRole.fromJson(Map<String, dynamic> j) => TeamRole(
        id: j['id'] as int,
        name: j['name'] as String,
        permissions: (j['permissions'] as List?)?.cast<String>() ?? const [],
        builtin: (j['builtin'] as bool?) ?? false,
      );
}

/// Thin wrapper over the /me/team endpoints. Surfaces the backend's
/// machine error string so the UI can show why a write was rejected.
class TeamService {
  TeamService(this._client);
  final ApiClient _client;

  String _error(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return _friendly(decoded['error'] as String, fallback);
      }
    } catch (_) {}
    return fallback;
  }

  String _friendly(String code, String fallback) {
    switch (code) {
      case 'ROLE_EXISTS':
        return 'A role with that name already exists.';
      case 'ROLE_NOT_FOUND':
        return 'That role no longer exists.';
      case 'INVALID_ROLE_NAME':
        return 'Enter a role name (1–60 characters).';
      case 'MEMBER_NOT_FOUND':
        return 'That teammate is no longer on the team.';
      case 'CANNOT_MODIFY_OWNER':
        return "The owner's access can't be changed.";
      case 'CANNOT_CHANGE_OWN_ROLE':
        return "You can't change your own access.";
      default:
        return code.contains(' ') ? code : fallback;
    }
  }

  // ── Members ─────────────────────────────────────────────────────
  Future<List<TeamMember>> listMembers() async {
    final res = await _client.get('/me/team/members');
    if (res.statusCode != 200) {
      throw Exception(_error(res.body, 'Could not load team'));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ((body['members'] as List?) ?? [])
        .map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<TeamInvite>> listInvites() async {
    final res = await _client.get('/me/team/invites');
    if (res.statusCode == 403) return const [];
    if (res.statusCode != 200) {
      throw Exception(_error(res.body, 'Could not load invitations'));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ((body['invites'] as List?) ?? [])
        .map((i) => TeamInvite.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<void> invite({
    required String email,
    required String roleName,
    required List<String> permissions,
  }) async {
    final res = await _client.post('/me/team/invites',
        body: {'email': email, 'roleName': roleName, 'permissions': permissions});
    if (res.statusCode != 201) {
      throw Exception(_error(res.body, 'Could not send invitation'));
    }
  }

  Future<void> setPermissions({
    required int userId,
    required String roleName,
    required List<String> permissions,
  }) async {
    final res = await _client.patch('/me/team/members/$userId/permissions',
        body: {'roleName': roleName, 'permissions': permissions});
    if (res.statusCode != 200) {
      throw Exception(_error(res.body, 'Could not update access'));
    }
  }

  Future<void> removeMember(int userId) async {
    final res = await _client.delete('/me/team/members/$userId');
    if (res.statusCode != 204) {
      throw Exception(_error(res.body, 'Could not remove member'));
    }
  }

  Future<void> cancelInvite(int inviteId) async {
    final res = await _client.delete('/me/team/invites/$inviteId');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_error(res.body, 'Could not cancel invitation'));
    }
  }

  // ── Roles ───────────────────────────────────────────────────────
  Future<List<TeamRole>> listRoles() async {
    final res = await _client.get('/me/team/roles');
    if (res.statusCode != 200) {
      throw Exception(_error(res.body, 'Could not load roles'));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ((body['roles'] as List?) ?? [])
        .map((r) => TeamRole.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<TeamRole> createRole(String name, List<String> permissions) async {
    final res = await _client
        .post('/me/team/roles', body: {'name': name, 'permissions': permissions});
    if (res.statusCode != 201) {
      throw Exception(_error(res.body, 'Could not create role'));
    }
    return TeamRole.fromJson(
        (jsonDecode(res.body) as Map<String, dynamic>)['role'] as Map<String, dynamic>);
  }

  Future<TeamRole> updateRole(int id, String name, List<String> permissions) async {
    final res = await _client
        .patch('/me/team/roles/$id', body: {'name': name, 'permissions': permissions});
    if (res.statusCode != 200) {
      throw Exception(_error(res.body, 'Could not save role'));
    }
    return TeamRole.fromJson(
        (jsonDecode(res.body) as Map<String, dynamic>)['role'] as Map<String, dynamic>);
  }

  Future<void> deleteRole(int id) async {
    final res = await _client.delete('/me/team/roles/$id');
    if (res.statusCode != 204) {
      throw Exception(_error(res.body, 'Could not delete role'));
    }
  }
}

// ── Permission area metadata (mirror of backend AREAS) ──────────────

class PermissionAreaInfo {
  const PermissionAreaInfo(this.key, this.label, {this.hint = '', this.viewOnly = false});
  final String key;
  final String label;
  final String hint;
  final bool viewOnly;
}

const List<PermissionAreaInfo> kPermissionAreaInfos = [
  PermissionAreaInfo('dashboard', 'Dashboard', hint: 'Home overview', viewOnly: true),
  PermissionAreaInfo('products', 'Products', hint: 'Catalogue, prices, stock items'),
  PermissionAreaInfo('orders', 'Orders', hint: 'Online orders inbox'),
  PermissionAreaInfo('invoices', 'Billing & POS', hint: 'Point of sale (till), bills, returns, cashier shifts'),
  PermissionAreaInfo('quotations', 'Quotations', hint: 'Price quotes / estimates sent to customers'),
  PermissionAreaInfo('challans', 'Challans', hint: 'Delivery / dispatch challans for goods'),
  PermissionAreaInfo('payments', 'Payments', hint: 'Receipts & payments'),
  PermissionAreaInfo('parties', 'Customers', hint: 'Customers & suppliers'),
  PermissionAreaInfo('stock', 'Stock', hint: 'Stock in / out & adjustments'),
  PermissionAreaInfo('vendors', 'Vendors', hint: 'Vendors / suppliers'),
  PermissionAreaInfo('marketing', 'Marketing', hint: 'Banners & coupons'),
  PermissionAreaInfo('shop', 'Shop', hint: 'Shop profile & settings'),
  PermissionAreaInfo('reports', 'Reports', hint: 'Sales reports', viewOnly: true),
  PermissionAreaInfo('payouts', 'Payouts', hint: 'Razorpay payouts'),
  PermissionAreaInfo('team', 'Team', hint: 'Team members & roles'),
];

/// Plain-language "what you can do" bullets derived from an actual grant
/// set — used on the join-request screen so the role is described by its
/// real access, not a hardcoded blurb. Manage beats view per area.
List<String> responsibilitiesFromPermissions(List<String> perms) {
  final set = perms.toSet();
  final out = <String>[];
  for (final a in kPermissionAreaInfos) {
    if (set.contains('${a.key}:manage')) {
      out.add('Manage ${a.label.toLowerCase()}');
    } else if (set.contains('${a.key}:view')) {
      out.add('View ${a.label.toLowerCase()}');
    }
  }
  return out;
}

/// Count of areas the grant set can *manage* — for compact summaries.
int manageableAreaCount(List<String> perms) =>
    perms.where((r) => r.endsWith(':manage')).length;

/// Normalise a grant set the way the backend does: every `:manage`
/// carries its `:view`.
Set<String> normalizeRights(Iterable<String> rights) {
  final out = <String>{};
  for (final r in rights) {
    out.add(r);
    if (r.endsWith(':manage')) out.add(r.replaceFirst(':manage', ':view'));
  }
  return out;
}

/// Legacy fallback label for the old enum role values.
String teamRoleLabel(String role) {
  switch (role) {
    case 'OWNER':
      return 'Owner';
    case 'MANAGER':
      return 'Manager';
    case 'STOCKIST':
      return 'Stockist';
    case 'CASHIER':
      return 'Cashier';
    default:
      return 'Staff';
  }
}
