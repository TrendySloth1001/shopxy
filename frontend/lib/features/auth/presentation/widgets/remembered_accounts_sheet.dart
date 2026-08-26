import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/remembered_accounts.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy/features/profile/presentation/pages/profile_page.dart'
    show ProfileAvatar;
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class RememberedAccountsButton extends StatefulWidget {
  const RememberedAccountsButton({super.key});

  @override
  State<RememberedAccountsButton> createState() =>
      _RememberedAccountsButtonState();
}

class _RememberedAccountsButtonState extends State<RememberedAccountsButton> {
  List<RememberedAccount> _accounts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<AuthProvider>().rememberedAccounts();
    if (mounted) setState(() => _accounts = list);
  }

  Future<void> _open() async {
    await showRememberedAccountsSheet(context);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_accounts.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final single = _accounts.length == 1 ? _accounts.first : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.tileBg(AppColors.brandSoft),
        shape: AppShapes.squircle(
          AppSizes.radiusFull,
          side: BorderSide(color: AppColors.brandSoft),
        ),
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusFull),
          onTap: _open,
          child: SizedBox(
            height: 50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AvatarCluster(accounts: _accounts),
                  const SizedBox(width: AppSizes.sm),
                  Flexible(
                    child: Text(
                      single != null
                          ? l10n.authContinueAsName(_displayName(single))
                          : l10n.authSavedAccounts,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarCluster extends StatelessWidget {
  const _AvatarCluster({required this.accounts});

  final List<RememberedAccount> accounts;

  static const double _size = 30;
  static const double _ring = 1.5;
  static const double _overlap = 10;
  static const double _step = _size - _overlap;

  @override
  Widget build(BuildContext context) {
    final shown = accounts.take(3).toList();
    return SizedBox(
      width: _size + (shown.length - 1) * _step,
      height: _size,
      child: Stack(
        children: [
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              left: i * _step,
              child: Container(
                width: _size,
                height: _size,
                foregroundDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.tileBg(AppColors.brandSoft),
                    width: _ring,
                  ),
                ),
                child: ProfileAvatar(
                  name: _displayName(shown[i]),
                  imageUrl: shown[i].avatarUrl,
                  size: _size,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showRememberedAccountsSheet(BuildContext context) {
  final auth = context.read<AuthProvider>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusDialog),
      ),
      side: BorderSide(color: AppColors.hairline),
    ),
    builder: (_) => _RememberedAccountsSheet(auth: auth),
  );
}

class _RememberedAccountsSheet extends StatefulWidget {
  const _RememberedAccountsSheet({required this.auth});

  final AuthProvider auth;

  @override
  State<_RememberedAccountsSheet> createState() =>
      _RememberedAccountsSheetState();
}

class _RememberedAccountsSheetState extends State<_RememberedAccountsSheet> {
  List<RememberedAccount>? _accounts;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.auth.rememberedAccounts();
    if (mounted) setState(() => _accounts = list);
  }

  Future<void> _resume(String id) async {
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await widget.auth.loginWithRemembered(id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyId = null;
        _error = friendlyError(e);
      });
      await _load();
    }
  }

  Future<void> _forget(String id) async {
    await widget.auth.forgetRemembered(id);
    await _load();
    if (mounted && (_accounts?.isEmpty ?? false)) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accounts = _accounts;
    final busy = _busyId != null;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                0,
                AppSizes.lg,
                AppSizes.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.authPickAccountTitle,
                    style: theme.textTheme.titleMedium?.extraBold,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    l10n.authPickAccountSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  0,
                  AppSizes.lg,
                  AppSizes.md,
                ),
                child: AuthErrorBanner(message: _error!),
              ),
            Flexible(
              child: accounts == null
                  ? const Padding(
                      padding: EdgeInsets.all(AppSizes.xl),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.lg,
                      ),
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSizes.sm),
                      itemBuilder: (_, i) => _AccountTile(
                        account: accounts[i],
                        busy: _busyId == accounts[i].id,
                        enabled: !busy,
                        onTap: () => _resume(accounts[i].id),
                        onForget: () => _forget(accounts[i].id),
                      ),
                    ),
            ),
            const SizedBox(height: AppSizes.sm),
            Divider(color: AppColors.hairline, height: 1),
            InkWell(
              onTap: busy ? null : () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: AppSizes.avatarSm,
                      height: AppSizes.avatarSm,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.tileBg(AppColors.brandSoft),
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(
                        AppIcons.personAddAlt1Rounded,
                        size: AppSizes.iconSm,
                        color: AppColors.brandStrong,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Text(
                        l10n.authUseAnotherAccount,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.onForget,
  });

  final RememberedAccount account;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = _displayName(account);

    return Material(
      color: AppColors.canvas,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: BorderSide(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              customBorder: AppShapes.squircle(AppSizes.radiusMd),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Row(
                  children: [
                    ProfileAvatar(
                      name: name,
                      imageUrl: account.avatarUrl,
                      size: AppSizes.avatarSm,
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (account.email.isNotEmpty)
                            Text(
                              account.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      AppIcon(
                        AppIcons.chevronRightRounded,
                        size: AppSizes.iconSm,
                        color: AppColors.subtle,
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: enabled ? onForget : null,
            icon: AppIcon(
              AppIcons.closeRounded,
              size: AppSizes.iconSm,
              color: AppColors.muted,
            ),
            tooltip: l10n.authRemoveThisAccount,
          ),
        ],
      ),
    );
  }
}

String _displayName(RememberedAccount a) =>
    a.name.trim().isNotEmpty ? a.name.trim() : a.email;
