import 'package:flutter/material.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/features/shop/data/team_service.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

/// Member-access editor returns the role label + exact grant.
typedef PermissionResult = ({String roleName, List<String> permissions});

/// Role create/edit returns a name + grant.
typedef RoleResult = ({String name, List<String> permissions});

// ─────────────────────────────────────────────────────────────────────
// Shared: a flat View/Manage matrix (divider rows, no boxes)
// ─────────────────────────────────────────────────────────────────────

class _PermissionMatrix extends StatelessWidget {
  const _PermissionMatrix({required this.granted, required this.onToggle});
  final Set<String> granted;
  final void Function(String area, String action, bool on) onToggle;

  bool _has(String area, String action) => granted.contains('$area:$action');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Column headers
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.sm,
            AppSizes.lg,
            AppSizes.xs,
          ),
          child: Row(
            children: [
              const Spacer(),
              _hdr(theme, l10n.shopPermissionView),
              const SizedBox(width: AppSizes.sm),
              _hdr(theme, l10n.shopPermissionManage),
            ],
          ),
        ),
        for (var i = 0; i < kPermissionAreaInfos.length; i++)
          _AreaRow(
            info: kPermissionAreaInfos[i],
            first: i == 0,
            view: _has(kPermissionAreaInfos[i].key, 'view'),
            manage: _has(kPermissionAreaInfos[i].key, 'manage'),
            onView: (v) => onToggle(kPermissionAreaInfos[i].key, 'view', v),
            onManage: (v) => onToggle(kPermissionAreaInfos[i].key, 'manage', v),
          ),
      ],
    );
  }

  Widget _hdr(ThemeData theme, String label) => SizedBox(
    width: 52,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: theme.textTheme.labelSmall?.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({
    required this.info,
    required this.first,
    required this.view,
    required this.manage,
    required this.onView,
    required this.onManage,
  });
  final PermissionAreaInfo info;
  final bool first;
  final bool view;
  final bool manage;
  final ValueChanged<bool> onView;
  final ValueChanged<bool> onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: first ? Colors.transparent : AppColors.hairline,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (info.hint.isNotEmpty)
                  Text(
                    info.hint,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 52,
            child: Checkbox(value: view, onChanged: (v) => onView(v ?? false)),
          ),
          const SizedBox(width: AppSizes.sm),
          SizedBox(
            width: 52,
            child: info.viewOnly
                ? AppIcon(
                    AppIcons.remove,
                    size: AppSizes.iconSm,
                    color: AppColors.subtle,
                  )
                : Checkbox(
                    value: manage,
                    onChanged: (v) => onManage(v ?? false),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Applies a toggle to a grant set honouring the invariants: manage⇒view,
/// and removing view removes manage.
Set<String> applyToggle(
  Set<String> granted,
  String area,
  String action,
  bool on,
) {
  final next = {...granted};
  final view = '$area:view';
  final manage = '$area:manage';
  if (action == 'view') {
    if (on) {
      next.add(view);
    } else {
      next
        ..remove(view)
        ..remove(manage);
    }
  } else {
    if (on) {
      next
        ..add(manage)
        ..add(view);
    } else {
      next.remove(manage);
    }
  }
  return next;
}

// ─────────────────────────────────────────────────────────────────────
// Member access editor — pick a role to pre-fill, then tweak
// ─────────────────────────────────────────────────────────────────────

class PermissionEditorPage extends StatefulWidget {
  const PermissionEditorPage({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.roles,
    this.initialRoleName,
    this.initialPermissions = const [],
    this.subtitle,
  });

  final String title;
  final String submitLabel;

  /// The shop's roles, offered as quick-fill chips.
  final List<TeamRole> roles;
  final String? initialRoleName;
  final List<String> initialPermissions;
  final String? subtitle;

  @override
  State<PermissionEditorPage> createState() => _PermissionEditorPageState();
}

class _PermissionEditorPageState extends State<PermissionEditorPage> {
  late Set<String> _granted;
  String? _roleName;

  @override
  void initState() {
    super.initState();
    _roleName = widget.initialRoleName;
    _granted = normalizeRights(widget.initialPermissions);
    // If no initial perms, seed from the named role (if it still exists).
    if (_granted.isEmpty && _roleName != null) {
      final r = _roleByName(_roleName!);
      if (r != null) _granted = normalizeRights(r.permissions);
    }
  }

  TeamRole? _roleByName(String name) {
    for (final r in widget.roles) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// The role whose normalised permissions exactly match the current set.
  TeamRole? get _matchingRole {
    for (final r in widget.roles) {
      final p = normalizeRights(r.permissions);
      if (p.length == _granted.length && p.containsAll(_granted)) return r;
    }
    return null;
  }

  void _applyRole(TeamRole r) {
    setState(() {
      _roleName = r.name;
      _granted = normalizeRights(r.permissions);
    });
  }

  void _toggle(String area, String action, bool on) {
    setState(() => _granted = applyToggle(_granted, area, action, on));
  }

  void _save() {
    final match = _matchingRole;
    final name = match?.name ?? _roleName ?? 'Custom';
    Navigator.pop<PermissionResult>(context, (
      roleName: name,
      permissions: _granted.toList()..sort(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final match = _matchingRole;
    final manageCount = manageableAreaCount(_granted.toList());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: widget.title,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              widget.submitLabel,
              style: Theme.of(context).textTheme.labelLarge?.extraBold,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.huge,
        ),
        children: [
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                0,
              ),
              child: Text(
                widget.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
          const SizedBox(height: AppSizes.lg),
          _Eyebrow(l10n.shopStartFromRole),
          const SizedBox(height: AppSizes.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final r in widget.roles)
                  _RoleChip(
                    label: r.name,
                    selected: match?.id == r.id,
                    onTap: () => _applyRole(r),
                  ),
                if (match == null && _granted.isNotEmpty)
                  _RoleChip(
                    label: l10n.shopCustomRole,
                    selected: true,
                    custom: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          _Eyebrow(l10n.shopAccessManageable(manageCount)),
          _PermissionMatrix(granted: _granted, onToggle: _toggle),
          const SizedBox(height: AppSizes.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text(
              l10n.shopPermissionTrustHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Role create/edit — name + the same matrix
// ─────────────────────────────────────────────────────────────────────

class RoleEditorPage extends StatefulWidget {
  const RoleEditorPage({
    super.key,
    this.initialName = '',
    this.initialPermissions = const [],
    this.isNew = true,
  });

  final String initialName;
  final List<String> initialPermissions;
  final bool isNew;

  @override
  State<RoleEditorPage> createState() => _RoleEditorPageState();
}

class _RoleEditorPageState extends State<RoleEditorPage> {
  late final TextEditingController _name;
  late Set<String> _granted;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _granted = normalizeRights(widget.initialPermissions);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggle(String area, String action, bool on) {
    setState(() => _granted = applyToggle(_granted, area, action, on));
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).shopGiveRoleName)),
      );
      return;
    }
    Navigator.pop<RoleResult>(context, (
      name: name,
      permissions: _granted.toList()..sort(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final manageCount = manageableAreaCount(_granted.toList());
    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: widget.isNew ? l10n.shopNewRole : l10n.shopEditRole,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              l10n.shopSave,
              style: Theme.of(context).textTheme.labelLarge?.extraBold,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.huge,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.lg,
              0,
            ),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.shopRoleNameLabel,
                hintText: l10n.shopRoleNameHint,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          _Eyebrow(l10n.shopAccessManageable(manageCount)),
          _PermissionMatrix(granted: _granted, onToggle: _toggle),
          const SizedBox(height: AppSizes.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text(
              l10n.shopRoleTemplatesHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── small shared bits ──────────────────────────────────────────────

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    this.onTap,
    this.custom = false,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool custom;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.brandStrong : AppColors.black;
    final bg = selected ? AppColors.brandSoft : AppColors.heroPanel;
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.brandStrong : AppColors.hairline,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (custom) ...[
                AppIcon(
                  AppIcons.tuneRounded,
                  size: AppSizes.iconSm,
                  color: AppColors.brandStrong,
                ),
                const SizedBox(width: AppSizes.xs),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
