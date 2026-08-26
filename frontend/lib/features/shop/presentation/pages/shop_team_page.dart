import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/shop/data/team_service.dart';
import 'package:shopxy/features/shop/presentation/pages/permission_editor_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class ShopTeamPage extends StatefulWidget {
  const ShopTeamPage({super.key});

  @override
  State<ShopTeamPage> createState() => _ShopTeamPageState();
}

class _ShopTeamPageState extends State<ShopTeamPage> {
  late final TeamService _service;
  bool _loading = true;
  String? _error;
  List<TeamMember> _members = const [];
  List<TeamInvite> _invites = const [];
  List<TeamRole> _roles = const [];

  @override
  void initState() {
    super.initState();
    _service = TeamService(context.read<ApiClient>());
    _load();
  }

  bool get _canManage =>
      context.read<AuthProvider>().user?.canManageTeam ?? false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.listMembers(),
        _service.listRoles(),
        _canManage ? _service.listInvites() : Future.value(<TeamInvite>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<TeamMember>;
        _roles = results[1] as List<TeamRole>;
        _invites = results[2] as List<TeamInvite>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<T?> _run<T>(Future<T> Function() op, String okMsg) async {
    try {
      final r = await op();
      _snack(okMsg);
      await _load();
      return r;
    } catch (e) {
      _snack(friendlyError(e));
      return null;
    }
  }

  Future<void> _invite() async {
    final l10n = AppLocalizations.of(context);
    final email = await _InviteSheet.show(context);
    if (email == null || !mounted) return;
    final access = await Navigator.push<PermissionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PermissionEditorPage(
          title: l10n.shopInviteAccessTitle,
          submitLabel: l10n.shopSendInvite,
          roles: _roles,
          initialRoleName: _roles.isNotEmpty ? _roles.first.name : null,
          subtitle: l10n.shopInviteAccessSubtitle(email),
        ),
      ),
    );
    if (access == null) return;
    if (!mounted) return;
    await _run(
      () => _service.invite(
        email: email,
        roleName: access.roleName,
        permissions: access.permissions,
      ),
      AppLocalizations.of(context).shopInvitationSentTo(email),
    );
  }

  Future<void> _editAccess(TeamMember m) async {
    final l10n = AppLocalizations.of(context);
    final access = await Navigator.push<PermissionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PermissionEditorPage(
          title: l10n.shopEditAccessTitle,
          submitLabel: l10n.shopSave,
          roles: _roles,
          initialRoleName: m.roleName,
          initialPermissions: m.permissions,
          subtitle: l10n.shopEditAccessSubtitle(
            m.name.isEmpty ? m.email : m.name,
          ),
        ),
      ),
    );
    if (access == null) return;
    if (!mounted) return;
    await _run(
      () => _service.setPermissions(
        userId: m.userId,
        roleName: access.roleName,
        permissions: access.permissions,
      ),
      AppLocalizations.of(context).shopAccessUpdated,
    );
  }

  Future<void> _remove(TeamMember m) async {
    final l10n = AppLocalizations.of(context);
    final ok = await AppConfirmDialog.show(
      context,
      title: l10n.shopRemoveFromTeamTitle,
      message: l10n.shopRemoveFromTeamMessage(
        m.name.isEmpty ? m.email : m.name,
      ),
      confirmLabel: l10n.shopRemove,
      danger: true,
    );
    if (!ok) return;
    if (!mounted) return;
    await _run(
      () => _service.removeMember(m.userId),
      AppLocalizations.of(context).shopRemovedFromTeam,
    );
  }

  Future<void> _createRole() async {
    final r = await Navigator.push<RoleResult>(
      context,
      MaterialPageRoute(builder: (_) => const RoleEditorPage(isNew: true)),
    );
    if (r == null) return;
    if (!mounted) return;
    await _run(
      () => _service.createRole(r.name, r.permissions),
      AppLocalizations.of(context).shopRoleCreated,
    );
  }

  Future<void> _editRole(TeamRole role) async {
    final r = await Navigator.push<RoleResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RoleEditorPage(
          isNew: false,
          initialName: role.name,
          initialPermissions: role.permissions,
        ),
      ),
    );
    if (r == null) return;
    if (!mounted) return;
    await _run(
      () => _service.updateRole(role.id, r.name, r.permissions),
      AppLocalizations.of(context).shopRoleSaved,
    );
  }

  Future<void> _deleteRole(TeamRole role) async {
    final l10n = AppLocalizations.of(context);
    final ok = await AppConfirmDialog.show(
      context,
      title: l10n.shopDeleteRoleTitle(role.name),
      message: l10n.shopDeleteRoleMessage,
      confirmLabel: l10n.shopDelete,
      danger: true,
    );
    if (!ok) return;
    if (!mounted) return;
    await _run(
      () => _service.deleteRole(role.id),
      AppLocalizations.of(context).shopRoleDeleted,
    );
  }

  Future<void> _cancelInvite(TeamInvite i) => _run(
    () => _service.cancelInvite(i.id),
    AppLocalizations.of(context).shopInvitationCancelled,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.shopTeamTitle,
        actions: [
          AccessReloadButton(onReload: _load),
          if (_canManage)
            IconButton(
              tooltip: l10n.shopInviteTeammate,
              onPressed: _loading ? null : _invite,
              icon: const AppIcon(AppIcons.personAddOutlined),
            ),
        ],
      ),
      body: _loading
          ? const _ShopTeamSkeleton()
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(onRefresh: _load, child: _content()),
    );
  }

  Widget _content() {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: EdgeInsets.only(
        top: AppSizes.md + FloatingAppBar.contentTopInset(context),
        bottom: AppSizes.huge,
      ),
      children: [
        if (!_canManage)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              0,
              AppSizes.lg,
              AppSizes.md,
            ),
            child: _InfoBanner(l10n.shopTeamViewOnlyBanner),
          ),

        _SectionHeader(l10n.shopTeamSectionHeader(_members.length)),
        for (var i = 0; i < _members.length; i++)
          _MemberRow(
            member: _members[i],
            first: i == 0,
            canManage: _canManage && !_members[i].isOwner,
            onEdit: () => _editAccess(_members[i]),
            onRemove: () => _remove(_members[i]),
          ),

        if (_invites.isNotEmpty) ...[
          const SizedBox(height: AppSizes.xl),
          _SectionHeader(l10n.shopPendingInvitesHeader(_invites.length)),
          for (var i = 0; i < _invites.length; i++)
            _InviteRow(
              invite: _invites[i],
              first: i == 0,
              canManage: _canManage,
              onCancel: () => _cancelInvite(_invites[i]),
            ),
        ],

        const SizedBox(height: AppSizes.xl),
        _SectionHeader(
          l10n.shopRolesHeader(_roles.length),
          action: _canManage
              ? _HeaderAction(
                  label: l10n.shopNewRole,
                  icon: AppIcons.addRounded,
                  onTap: _createRole,
                )
              : null,
        ),
        for (var i = 0; i < _roles.length; i++)
          _RoleRow(
            role: _roles[i],
            first: i == 0,
            canManage: _canManage,
            onEdit: () => _editRole(_roles[i]),
            onDelete: () => _deleteRole(_roles[i]),
          ),
      ],
    );
  }
}

class _ShopTeamSkeleton extends StatelessWidget {
  const _ShopTeamSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        top: AppSizes.md + FloatingAppBar.contentTopInset(context),
        bottom: AppSizes.huge,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            0,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: AppShimmerBox(
            width: double.infinity,
            height: 52,
            radius: AppSizes.radiusMd,
          ),
        ),

        const _SkeletonSectionHeader(),

        for (var i = 0; i < 4; i++) _SkeletonMemberRow(first: i == 0),

        const SizedBox(height: AppSizes.xl),
        const _SkeletonSectionHeader(),

        for (var i = 0; i < 2; i++) _SkeletonInviteRow(first: i == 0),

        const SizedBox(height: AppSizes.xl),
        const _SkeletonSectionHeader(withAction: true),

        for (var i = 0; i < 3; i++) _SkeletonRoleRow(first: i == 0),
      ],
    );
  }
}

class _SkeletonSectionHeader extends StatelessWidget {
  const _SkeletonSectionHeader({this.withAction = false});
  final bool withAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          AppShimmerLine(widthFactor: 0.35, height: 11),
          if (withAction) ...[
            const Spacer(),
            AppShimmerBox(width: 72, height: 22, radius: AppSizes.radiusFull),
          ],
        ],
      ),
    );
  }
}

class _SkeletonMemberRow extends StatelessWidget {
  const _SkeletonMemberRow({required this.first});
  final bool first;

  @override
  Widget build(BuildContext context) {
    return _Divided(
      first: first,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            AppShimmerBox(
              width: AppSizes.avatarSm,
              height: AppSizes.avatarSm,
              radius: AppSizes.avatarSm / 2,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerLine(widthFactor: 0.55, height: 14),
                  const SizedBox(height: 5),
                  AppShimmerLine(widthFactor: 0.75, height: 11),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            AppShimmerBox(width: 56, height: 22, radius: AppSizes.radiusFull),
            const SizedBox(width: AppSizes.sm),
            AppShimmerBox(width: 20, height: 20, radius: AppSizes.radiusFull),
          ],
        ),
      ),
    );
  }
}

class _SkeletonInviteRow extends StatelessWidget {
  const _SkeletonInviteRow({required this.first});
  final bool first;

  @override
  Widget build(BuildContext context) {
    return _Divided(
      first: first,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            AppShimmerBox(width: 20, height: 20, radius: AppSizes.radiusSm),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerLine(widthFactor: 0.65, height: 14),
                  const SizedBox(height: 5),
                  AppShimmerLine(widthFactor: 0.50, height: 11),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            AppShimmerBox(width: 60, height: 28, radius: AppSizes.radiusSm),
          ],
        ),
      ),
    );
  }
}

class _SkeletonRoleRow extends StatelessWidget {
  const _SkeletonRoleRow({required this.first});
  final bool first;

  @override
  Widget build(BuildContext context) {
    return _Divided(
      first: first,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            AppShimmerBox(width: 20, height: 20, radius: AppSizes.radiusSm),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppShimmerLine(widthFactor: 0.40, height: 14),
                      const SizedBox(width: AppSizes.sm),
                      AppShimmerBox(
                        width: 52,
                        height: 18,
                        radius: AppSizes.radiusFull,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  AppShimmerLine(widthFactor: 0.55, height: 11),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            AppShimmerBox(width: 20, height: 20, radius: AppSizes.radiusFull),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.first,
    required this.canManage,
    required this.onEdit,
    required this.onRemove,
  });
  final TeamMember member;
  final bool first;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = member.name.isEmpty ? member.email : member.name;
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          _Avatar(name: name),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.extraBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  member.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          _RolePill(label: member.label, owner: member.isOwner),
          if (canManage)
            PopupMenuButton<String>(
              icon: AppIcon(AppIcons.moreVert, color: AppColors.subtle),
              onSelected: (v) => v == 'edit' ? onEdit() : onRemove(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(l10n.shopEditAccessMenu),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    l10n.shopRemoveFromTeamMenu,
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: AppSizes.sm),
        ],
      ),
    );
    return _Divided(
      first: first,
      child: canManage ? InkWell(onTap: onEdit, child: row) : row,
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.first,
    required this.canManage,
    required this.onCancel,
  });
  final TeamInvite invite;
  final bool first;
  final bool canManage;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return _Divided(
      first: first,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.mailOutlineRounded, color: AppColors.muted),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.email,
                    style: theme.textTheme.bodyLarge?.bold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    l10n.shopInvitedAsAwaitingReply(invite.roleName),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (canManage)
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(l10n.shopCancel),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.role,
    required this.first,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });
  final TeamRole role;
  final bool first;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final manage = manageableAreaCount(role.permissions);
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.badgeOutlined, color: AppColors.subtle),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        role.name,
                        style: theme.textTheme.bodyLarge?.extraBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (role.builtin) ...[
                      const SizedBox(width: AppSizes.sm),
                      _MiniTag(l10n.shopBuiltIn),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  manage == 0
                      ? l10n.shopRoleViewOnly
                      : (manage == 1
                            ? l10n.shopRoleAreaManageable(manage)
                            : l10n.shopRoleAreasManageable(manage)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: AppIcon(AppIcons.moreVert, color: AppColors.subtle),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(l10n.shopEditRoleMenu),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    l10n.shopDeleteRoleMenu,
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    return _Divided(
      first: first,
      child: canManage ? InkWell(onTap: onEdit, child: row) : row,
    );
  }
}

class _Divided extends StatelessWidget {
  const _Divided({required this.first, required this.child});
  final bool first;
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: first ? Colors.transparent : AppColors.hairline),
      ),
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final AppIconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusFull),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: AppSizes.iconSm, color: AppColors.brandStrong),
            const SizedBox(width: AppSizes.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.brandStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.owner});
  final String label;
  final bool owner;
  @override
  Widget build(BuildContext context) {
    final fg = owner ? AppColors.brandStrong : AppColors.accentIndigo;
    final bg = owner ? AppColors.brandSoft : AppColors.accentIndigoSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 3),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: ShapeDecoration(
      color: AppColors.heroPanel,
      shape: AppShapes.squircle(AppSizes.radiusFull),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.avatarSm,
    height: AppSizes.avatarSm,
    decoration: BoxDecoration(
      color: AppColors.tileBg(AppColors.brandSoft),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.brandStrong,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.infoSoft,
    shape: AppShapes.squircle(AppSizes.radiusMd),
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcons.infoOutline, color: AppColors.info, size: 18),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.info),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: true,
    bottom: false,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.errorOutline, color: AppColors.muted, size: 40),
            const SizedBox(height: AppSizes.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).shopTryAgain),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet();

  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: AppShapes.squircleTop(AppSizes.radiusLg),
        builder: (_) => const _InviteSheet(),
      );

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop<String>(context, _email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.lg,
        right: AppSizes.lg,
        top: AppSizes.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shopInviteTeammate,
              style: theme.textTheme.titleLarge?.extraBold,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              l10n.shopInviteSheetSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: l10n.shopEmail,
                hintText: 'teammate@example.com',
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return l10n.shopEnterEmail;
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                  return l10n.shopEnterValidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSizes.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _next,
                icon: const AppIcon(AppIcons.arrowForwardRounded, size: 18),
                label: Text(l10n.shopChooseAccess),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
