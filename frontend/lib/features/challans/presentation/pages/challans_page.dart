import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/challans/presentation/pages/challan_detail_page.dart';
import 'package:shopxy/features/challans/presentation/pages/create_challan_page.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class ChallansPage extends StatefulWidget {
  const ChallansPage({super.key});

  @override
  State<ChallansPage> createState() => _ChallansPageState();
}

class _ChallansPageState extends State<ChallansPage> {
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChallansProvider>().loadChallans();
    });
  }

  @override
  void dispose() {
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final provider = context.read<ChallansProvider>();
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateChallanPage()),
    );
    if (created == true && mounted) {
      provider.loadChallans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<ChallansProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.challansTitle,
        actions: [AccessReloadButton(onReload: () => provider.loadChallans())],
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                0,
              ),
              child: AppSearchBar(
                hint: l10n.challansSearchHint,
                onChanged: context.read<ChallansProvider>().setSearch,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: AppSizes.sm,
              ),
              child: Row(
                children: <String?>[null, 'PENDING', 'CONVERTED', 'CANCELLED']
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: AppSizes.sm),
                        child: FilterChip(
                          label: Text(s ?? l10n.challansFilterAll),
                          selected: provider.statusFilter == s,
                          onSelected: (_) =>
                              context.read<ChallansProvider>().setStatus(s),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: provider.isLoading && provider.challans.isEmpty
                  ? const _ChallanListSkeleton()
                  : provider.error != null && provider.challans.isEmpty
                  ? AppErrorView(
                      onRetry: () =>
                          context.read<ChallansProvider>().loadChallans(),
                    )
                  : provider.challans.isEmpty
                  ? EmptyState.line(
                      kind: LineArt.deliveryNote,
                      title: l10n.challansEmptyTitle,
                      subtitle: l10n.challansEmptySubtitle,
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          context.read<ChallansProvider>().loadChallans(),
                      color: AppColors.black,
                      backgroundColor: AppColors.surface,
                      child: ListView.separated(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.lg,
                          AppSizes.sm,
                          AppSizes.lg,
                          AppSizes.fabClearance,
                        ),
                        itemCount: provider.challans.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSizes.sm),
                        itemBuilder: (ctx, i) {
                          final c = provider.challans[i];
                          return _ChallanTile(
                            challan: c,
                            onTap: () async {
                              final challansProvider = context
                                  .read<ChallansProvider>();
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ChallanDetailPage(challanId: c.id),
                                ),
                              );
                              if (changed == true && mounted) {
                                challansProvider.loadChallans();
                              }
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: MaybeLocked(
        allowed: context.select<AuthProvider, bool>(
          (a) => a.user?.canManage('challans') ?? false,
        ),
        what: 'create challans',
        child: FloatingActionButton.extended(
          onPressed: _openCreate,
          icon: const AppIcon(AppIcons.addRounded),
          label: Text(l10n.challansCreate),
        ),
      ),
    );
  }
}

AppStatusTone challanStatusTone(String status) {
  switch (status) {
    case 'CONVERTED':
      return AppStatusTone.success;
    case 'CANCELLED':
      return AppStatusTone.error;
    default:
      return AppStatusTone.neutral;
  }
}

class _ChallanListSkeleton extends StatelessWidget {
  const _ChallanListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.sm,
      ),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (_, _) => const _ChallanTileSkeleton(),
    );
  }
}

class _ChallanTileSkeleton extends StatelessWidget {
  const _ChallanTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          AppShimmerBox(width: 48, height: 48, radius: AppSizes.sm),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 1.0, height: 14),
                const SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.7, height: 12),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          AppShimmerBox(width: 64, height: 24, radius: AppSizes.xs),
        ],
      ),
    );
  }
}

class _ChallanTile extends StatelessWidget {
  const _ChallanTile({required this.challan, required this.onTap});
  final dynamic challan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy');

    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            children: [
              const AppIconAvatar.outlined(icon: AppIcons.receiptLongRounded),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challan.challanNo as String,
                      style: theme.textTheme.bodyLarge?.medium,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      '${challan.partyName} • ${df.format(challan.createdAt as DateTime)} • ${challan.itemCount} ${l10n.challansItemsLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              AppStatusBadge(
                label: challan.status as String,
                tone: challanStatusTone(challan.status as String),
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
