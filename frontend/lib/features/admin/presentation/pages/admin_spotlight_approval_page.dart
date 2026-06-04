import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/admin_spotlight.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_spotlight_provider.dart';
import 'package:shopxy/features/spotlight/data/models/spotlight.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Platform-admin queue for brand spotlight requests. Defaults to the
/// PENDING filter — the actionable queue — with chips to swap to the
/// APPROVED / REJECTED history.
class AdminSpotlightApprovalPage extends StatefulWidget {
  const AdminSpotlightApprovalPage({super.key});

  @override
  State<AdminSpotlightApprovalPage> createState() =>
      _AdminSpotlightApprovalPageState();
}

class _AdminSpotlightApprovalPageState
    extends State<AdminSpotlightApprovalPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminSpotlightProvider>().load();
    });
  }

  Future<void> _confirmApprove(AdminSpotlight s) async {
    final ok = await context.read<AdminSpotlightProvider>().approve(s.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approve failed')),
      );
    }
  }

  Future<void> _confirmReject(AdminSpotlight s) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject spotlight'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (visible to merchant)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    final ok = await context.read<AdminSpotlightProvider>().reject(s.id, reason);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reject failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminSpotlightProvider>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Spotlight approvals'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : () => provider.load(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: Wrap(
              spacing: AppSizes.sm,
              children: [
                _FilterChip(
                  label: 'Pending',
                  active: provider.filter == SpotlightStatus.pending,
                  onTap: () => provider.setFilter(SpotlightStatus.pending),
                ),
                _FilterChip(
                  label: 'Approved',
                  active: provider.filter == SpotlightStatus.approved,
                  onTap: () => provider.setFilter(SpotlightStatus.approved),
                ),
                _FilterChip(
                  label: 'Rejected',
                  active: provider.filter == SpotlightStatus.rejected,
                  onTap: () => provider.setFilter(SpotlightStatus.rejected),
                ),
                _FilterChip(
                  label: 'All',
                  active: provider.filter == null,
                  onTap: () => provider.setFilter(null),
                ),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoading && provider.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.items.isEmpty
                    ? const Center(child: Text('Nothing to review'))
                    : RefreshIndicator(
                        onRefresh: provider.load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.lg,
                            AppSizes.sm,
                            AppSizes.lg,
                            AppSizes.huge,
                          ),
                          itemCount: provider.items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSizes.md),
                          itemBuilder: (_, i) {
                            final s = provider.items[i];
                            return _ApprovalCard(
                              spotlight: s,
                              onApprove: s.status == SpotlightStatus.pending
                                  ? () => _confirmApprove(s)
                                  : null,
                              onReject: s.status == SpotlightStatus.pending
                                  ? () => _confirmReject(s)
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.spotlight,
    this.onApprove,
    this.onReject,
  });
  final AdminSpotlight spotlight;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd().add_jm();
    final bg = _parseColor(spotlight.bgColor);
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: bg,
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: AppColors.heroPanel,
                    shape: AppShapes.squircle(AppSizes.radiusMd),
                  ),
                  child: Image.network(
                    resolveImageUrl(spotlight.heroImageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spotlight.dealLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (spotlight.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          spotlight.subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        spotlight.shop.name,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: AppSizes.iconSm, color: AppColors.muted),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        '${df.format(spotlight.startAt)}  →  ${df.format(spotlight.endAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (spotlight.ctaTarget != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.link,
                        size: AppSizes.iconSm,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(child: Text(spotlight.ctaTarget!)),
                    ],
                  ),
                ],
                if (spotlight.status == SpotlightStatus.rejected &&
                    spotlight.rejectionReason != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: ShapeDecoration(
                      color: AppColors.errorSoft,
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                    ),
                    child: Text(
                      'Rejected: ${spotlight.rejectionReason!}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
                if (onApprove != null || onReject != null) ...[
                  const SizedBox(height: AppSizes.md),
                  Row(
                    children: [
                      if (onReject != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onReject,
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ),
                      if (onReject != null && onApprove != null)
                        const SizedBox(width: AppSizes.md),
                      if (onApprove != null)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onApprove,
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String hex, {Color fallback = AppColors.heroPanel}) {
  final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
  if (m == null) return fallback;
  var raw = m.group(1)!;
  if (raw.length == 6) raw = 'FF$raw';
  return Color(int.parse(raw, radix: 16));
}
