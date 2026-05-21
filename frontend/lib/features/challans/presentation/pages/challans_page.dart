import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/presentation/pages/challan_detail_page.dart';
import 'package:shopxy/features/challans/presentation/pages/create_challan_page.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

class ChallansPage extends StatefulWidget {
  const ChallansPage({super.key});

  @override
  State<ChallansPage> createState() => _ChallansPageState();
}

class _ChallansPageState extends State<ChallansPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChallansProvider>().loadChallans();
    });
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
    final provider = context.watch<ChallansProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navChallans)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              0,
            ),
            child: AppSearchBar(
              hint: AppStrings.searchChallans,
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
              children:
                  <String?>[null, 'PENDING', 'CONVERTED', 'CANCELLED']
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: AppSizes.sm),
                          child: FilterChip(
                            label: Text(s ?? AppStrings.all),
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
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.challans.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: AppStrings.noChallans,
                        subtitle: AppStrings.challansTapCreate,
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            context.read<ChallansProvider>().loadChallans(),
                        color: AppColors.black,
                        backgroundColor: AppColors.white,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.sm,
                          ).copyWith(bottom: 100),
                          itemCount: provider.challans.length,
                          separatorBuilder: (_, _) => const AppDivider(),
                          itemBuilder: (ctx, i) {
                            final c = provider.challans[i];
                            return _ChallanTile(
                              challan: c,
                              onTap: () async {
                                final challansProvider =
                                    context.read<ChallansProvider>();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.createChallan),
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

class _ChallanTile extends StatelessWidget {
  const _ChallanTile({required this.challan, required this.onTap});
  final dynamic challan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy');

    return Material(
      color: AppColors.white,
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
              const AppIconAvatar.outlined(icon: Icons.receipt_long_rounded),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challan.challanNo as String,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${challan.partyName} • ${df.format(challan.createdAt as DateTime)} • ${challan.itemCount} ${AppStrings.items}',
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
