import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_v2_page.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';
import 'package:shopxy_customer/features/search/data/datasources/marketplace_search_remote_data_source.dart';
import 'package:shopxy_customer/features/search/presentation/providers/search_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_filter_chip.dart';
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
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
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
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          bottom: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.canvas,
              border: Border(
                bottom: BorderSide(color: AppColors.hairline),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSizes.sm,
              AppSizes.sm,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
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
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusInput,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: AppStrings.searchProducts,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.md + 2,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.muted,
          ),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                  tooltip: AppStrings.cancel,
                ),
        ),
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
              const Icon(
                Icons.search_rounded,
                size: 48,
                color: AppColors.muted,
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
          Text(
            'Trending searches',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              for (final h in p.hints)
                AppFilterChip(
                  label: h,
                  selected: false,
                  icon: Icons.local_fire_department_outlined,
                  onTap: () => _apply(context, h),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
        ],
        if (p.recentSearches.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent searches',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              TextButton(
                onPressed: p.clearRecent,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              for (final q in p.recentSearches)
                AppFilterChip(
                  label: q,
                  selected: false,
                  icon: Icons.history_rounded,
                  onTap: () => _apply(context, q),
                ),
            ],
          ),
        ],
      ],
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
          AppShimmerBox(width: 56, height: 56, radius: 12),
          SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.7, height: 12),
                SizedBox(height: 6),
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
        if (i == 0) return _SemanticBadge(semantic: semantic, count: results.length);
        final p = results[i - 1];
        return InkWell(
          onTap: () {
            context.read<SearchProvider>().commitRecent();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailV2Page(productId: p.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  child: Container(
                    width: 56, height: 56,
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
                      const SizedBox(height: 2),
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
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.success, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '${p.ratingAvg!.toStringAsFixed(1)} (${p.ratingCount})',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
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
            size: 14,
            color: semantic ? AppColors.brand : AppColors.muted,
          ),
          const SizedBox(width: 4),
          Text(
            semantic
                ? '$count results · ranked by AI'
                : '$count results',
            style: TextStyle(
              color: semantic ? AppColors.brand : AppColors.muted,
              fontSize: 11,
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
              size: 48,
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
