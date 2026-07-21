import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/datasources/admin_shops_remote_data_source.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

/// Admin-only listing of marketplace shops with a verified toggle.
/// Gated by the `isPlatformAdmin` drawer entry. No bulk actions yet —
/// the row count is naturally small and individual toggles + search
/// cover the verification backlog today.
class AdminShopsPage extends StatefulWidget {
  const AdminShopsPage({super.key});

  @override
  State<AdminShopsPage> createState() => _AdminShopsPageState();
}

class _AdminShopsPageState extends State<AdminShopsPage> {
  final _searchCtrl = TextEditingController();
  List<AdminShopRow> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<AdminShopsRemoteDataSource>();
      final rows = await ds.list(search: _searchCtrl.text.trim());
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(AdminShopRow row) async {
    try {
      final ds = context.read<AdminShopsRemoteDataSource>();
      final updated = await ds.setVerified(row.id, !row.isVerified);
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final r in _rows)
            if (r.id == row.id) updated else r,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.adminShopsTitle,
        actions: [
          IconButton(
            tooltip: l10n.adminRefresh,
            icon: const AppIcon(AppIcons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
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
                AppSizes.sm,
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: l10n.adminShopsSearchHint,
                  prefixIcon: const AppIcon(AppIcons.search),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const AppIcon(AppIcons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                          },
                        ),
                ),
                onSubmitted: (_) => _load(),
                textInputAction: TextInputAction.search,
              ),
            ),
            Expanded(
              child: _loading && _rows.isEmpty
                  ? const _ShopsLoadingSkeleton()
                  : _error != null && _rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.xl),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    )
                  : _rows.isEmpty
                  ? const _EmptyBlock()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.lg,
                          0,
                          AppSizes.lg,
                          96,
                        ),
                        itemCount: _rows.length,
                        itemBuilder: (_, i) => _Row(
                          row: _rows[i],
                          onToggle: () => _toggle(_rows[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.onToggle});
  final AdminShopRow row;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: row.logoUrl == null
                      ? Container(
                          color: AppColors.heroPanel,
                          alignment: Alignment.center,
                          child: AppIcon(
                            AppIcons.storefrontOutlined,
                            color: AppColors.muted,
                          ),
                        )
                      : Image.network(
                          resolveImageUrl(row.logoUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: AppColors.heroPanel),
                        ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.name,
                            style: theme.textTheme.bodyLarge?.extraBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (row.isVerified) ...[
                          const SizedBox(width: AppSizes.sm),
                          AppStatusBadge(
                            label: l10n.adminShopVerified,
                            tone: AppStatusTone.info,
                            weight: AppStatusWeight.soft,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/${row.slug}'
                      '${row.isPublished ? "" : " · ${l10n.adminShopDraft}"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    if (row.locationCity != null || row.locationState != null)
                      Text(
                        [
                          row.locationCity,
                          row.locationState,
                        ].where((s) => s != null && s.isNotEmpty).join(', '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Switch.adaptive(
                value: row.isVerified,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-page skeleton shown while the initial shop list is loading.
class _ShopsLoadingSkeleton extends StatelessWidget {
  const _ShopsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, 0, AppSizes.lg, 96),
      itemCount: 5,
      itemBuilder: (_, _) => const _ShopRowSkeleton(),
    );
  }
}

/// Single skeleton row that mirrors the shape of [_Row].
class _ShopRowSkeleton extends StatelessWidget {
  const _ShopRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              // Logo placeholder — 44×44 rounded block.
              AppShimmerBox(width: 44, height: 44, radius: AppSizes.radiusSm),
              const SizedBox(width: AppSizes.md),
              // Text column.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shop name line (bold, ~70 % width).
                    AppShimmerLine(widthFactor: 0.7, height: 14),
                    const SizedBox(height: 6),
                    // Slug / status line (~50 % width).
                    AppShimmerLine(widthFactor: 0.5, height: 11),
                    const SizedBox(height: 4),
                    // Optional location line (~40 % width).
                    AppShimmerLine(widthFactor: 0.4, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              // Toggle switch placeholder.
              AppShimmerBox(width: 46, height: 26, radius: 13),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            AppIcons.storefrontOutlined,
            size: AppSizes.iconHuge,
            color: AppColors.subtle,
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            AppLocalizations.of(context).adminShopsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
