import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/marketplace/presentation/widgets/filter_sheet.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';
import 'package:shopxy_customer/features/search/data/datasources/marketplace_search_remote_data_source.dart';
import 'package:shopxy_customer/features/search/presentation/providers/search_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

/// Global product search. Opened from the home page's search entry
/// and pushed full-screen so the keyboard and the chip strip can
/// both fit without competing for vertical space.
///
/// Behaviour:
/// * Idle (no query) → recent searches as chips + empty hint.
/// * Typing → debounced search (220ms) with skeleton state.
/// * Results → list rows with thumbnail + price + tap-to-detail.
/// * No matches → empty state with the typed query echoed back.
/// * Error → AppErrorView-style block with retry.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery});

  // Pre-seeds the search box + provider when a caller wants to land
  // straight on results (e.g. tapping a curated home-feed rail).
  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery ?? '');
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final q = widget.initialQuery;
      if (q != null && q.isNotEmpty) {
        context.read<SearchProvider>().setQuery(q);
      } else {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onSubmit(String _) {
    context.read<SearchProvider>().commitRecent();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SearchProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: SafeArea(
          bottom: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.canvas,
              border: Border(
                bottom: BorderSide(color: AppColors.hairline, width: 0.6),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.sm,
              AppSizes.lg,
              AppSizes.md,
            ),
            child: Row(
              children: [
                _BackChip(onTap: () => Navigator.pop(context)),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _SearchField(
                    controller: _ctrl,
                    focusNode: _focus,
                    onChanged: p.setQuery,
                    onSubmitted: _onSubmit,
                    onClear: p.query.isEmpty
                        ? null
                        : () {
                            _ctrl.clear();
                            p.clear();
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _Body(provider: p, controller: _ctrl),
    );
  }
}

class _BackChip extends StatelessWidget {
  const _BackChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: AppSizes.tapTargetMin,
        height: AppSizes.tapTargetMin,
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline, width: 0.6),
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.black,
          size: AppSizes.iconMd,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.tapTargetMin,
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline, width: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: ShapeDecoration(
              color: AppColors.brand,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.search_rounded,
              color: AppColors.white,
              size: AppSizes.iconSm,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
              decoration: InputDecoration(
                hintText: AppStrings.searchProducts,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppColors.heroPanel,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.muted,
                  size: AppSizes.iconSm,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.controller});
  final SearchProvider provider;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    if (!provider.hasCommittedQuery) {
      return _IdleView(controller: controller);
    }
    if (provider.isLoading && provider.results.isEmpty) {
      return const _LoadingResults();
    }
    if (provider.error != null) {
      return _ErrorBlock(message: provider.error!);
    }
    if (provider.results.isEmpty) {
      return _NoMatches(query: provider.query);
    }
    return _ResultsList(results: provider.results, semantic: provider.isSemantic);
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.controller});
  final TextEditingController controller;

  void _apply(BuildContext context, String q) {
    controller.text = q;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: q.length),
    );
    context.read<SearchProvider>().applyTerm(q);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SearchProvider>();
    final theme = Theme.of(context);
    final hasContent = p.recentSearches.isNotEmpty || p.hints.isNotEmpty;

    if (!hasContent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.search_rounded,
                  size: AppSizes.iconXl,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                'Find a product',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                'Search by name, brand, or what you need it for —\n'
                'the engine understands intent, not just exact words.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.huge,
      ),
      children: [
        if (p.hints.isNotEmpty) ...[
          const _SectionHeading(
            eyebrow: 'POPULAR RIGHT NOW',
            title: 'Trending searches',
            icon: Icons.local_fire_department_rounded,
          ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              for (final h in p.hints)
                _TrendingChip(
                  label: h,
                  onTap: () => _apply(context, h),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.xl),
        ],
        if (p.recentSearches.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                child: _SectionHeading(
                  eyebrow: 'YOUR HISTORY',
                  title: 'Recent searches',
                  icon: Icons.history_rounded,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: p.clearRecent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.sm,
                  ),
                  decoration: ShapeDecoration(
                    color: Colors.transparent,
                    shape: AppShapes.squircle(
                      AppSizes.radiusSm,
                      side: const BorderSide(
                        color: AppColors.hairline,
                        width: 0.6,
                      ),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Column(
            children: [
              for (var i = 0; i < p.recentSearches.length; i++) ...[
                _RecentRow(
                  label: p.recentSearches[i],
                  onTap: () => _apply(context, p.recentSearches[i]),
                ),
                if (i < p.recentSearches.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 0.6,
                    color: AppColors.hairline,
                  ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.icon,
  });
  final String eyebrow;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.brand,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Row(
          children: [
            Icon(icon, color: AppColors.black, size: AppSizes.iconMd),
            const SizedBox(width: AppSizes.sm),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                height: 1.15,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendingChip extends StatelessWidget {
  const _TrendingChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: const BorderSide(color: AppColors.hairline, width: 0.6),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.sm,
            AppSizes.sm,
            AppSizes.md,
            AppSizes.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.brand,
                  size: AppSizes.iconSm,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.heroPanel,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.muted,
                size: AppSizes.iconSm,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            const Icon(
              Icons.north_west_rounded,
              color: AppColors.muted,
              size: AppSizes.iconSm,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingResults extends StatelessWidget {
  const _LoadingResults();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      itemCount: 6,
      separatorBuilder: (_, index) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, index) => Row(
        children: const [
          AppShimmerBox(
              width: AppSizes.avatarMd,
              height: AppSizes.avatarMd,
              radius: AppSizes.radiusMd),
          SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.7, height: 12),
                SizedBox(height: AppSizes.sm),
                AppShimmerLine(widthFactor: 0.4, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.semantic});
  final List<MarketplaceSearchHit> results;
  final bool semantic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      itemCount: results.length + 1,
      separatorBuilder: (_, index) =>
          const Divider(height: 1, color: AppColors.hairline),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Row(
            children: [
              Expanded(
                child:
                    _SemanticBadge(semantic: semantic, count: results.length),
              ),
              _FilterButton(
                onTap: () async {
                  final p = context.read<SearchProvider>();
                  final facets = p.facets;
                  if (facets == null) return;
                  final next = await showFilterSheet(
                    context: context,
                    initial: p.filters,
                    facets: facets,
                  );
                  if (next != null) p.setFilters(next);
                },
                activeCount: context.watch<SearchProvider>().filters.activeCount,
                disabled: context.watch<SearchProvider>().facets == null,
              ),
            ],
          );
        }
        final p = results[i - 1];
        return InkWell(
          onTap: () {
            context.read<SearchProvider>().commitRecent();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailPage(productId: p.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                  child: Container(
                    width: AppSizes.avatarMd,
                    height: AppSizes.avatarMd,
                    color: AppColors.heroPanel,
                    child: p.imageUrl == null || p.imageUrl!.isEmpty
                        ? const Icon(Icons.image_outlined, color: AppColors.muted)
                        : NetworkImageBox(url: resolveImageUrl(p.imageUrl!)),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSizes.xs),
                      if (p.shopName.isNotEmpty)
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopProfilePage(slug: p.shopSlug),
                            ),
                          ),
                          child: Text(
                            'by ${p.shopName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (p.ratingAvg != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSizes.xs),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.success, size: AppSizes.iconSm),
                              const SizedBox(width: AppSizes.xs),
                              Text(
                                '${p.ratingAvg!.toStringAsFixed(1)} (${p.ratingCount})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                AppPriceText.compact(p.sellingPrice),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small badge above results telling the user whether the result set
/// was ranked by the hybrid semantic + FTS engine or fell back to
/// pure FTS (e.g. when `OPENAI_API_KEY` isn't set on the backend).
/// Cheap honesty signal — useful both for QA and for users who care
/// why the ranking looks the way it does.
class _SemanticBadge extends StatelessWidget {
  const _SemanticBadge({required this.semantic, required this.count});
  final bool semantic;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        children: [
          Icon(
            semantic ? Icons.auto_awesome_rounded : Icons.search_rounded,
            size: AppSizes.iconSm,
            color: semantic ? AppColors.brand : AppColors.muted,
          ),
          const SizedBox(width: AppSizes.xs),
          Text(
            semantic
                ? '$count results · ranked by AI'
                : '$count results',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: semantic ? AppColors.brand : AppColors.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: AppSizes.iconHuge,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'No matches for "$query"',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Try a different spelling or a broader term.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.onTap,
    required this.activeCount,
    required this.disabled,
  });
  final VoidCallback onTap;
  final int activeCount;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    return TextButton.icon(
      onPressed: disabled ? null : onTap,
      icon: Icon(
        Icons.tune_rounded,
        size: AppSizes.iconMd,
        color: hasActive ? AppColors.brand : AppColors.muted,
      ),
      label: Text(
        hasActive ? 'Filters · $activeCount' : 'Filters',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: hasActive ? AppColors.brand : AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
      ),
    );
  }
}
