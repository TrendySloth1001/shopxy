import 'package:flutter/material.dart';
import 'package:shopxy/core/haptics/app_haptics.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/infographic_pie.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

class Analytics extends StatelessWidget {
  const Analytics({super.key, required this.insights});
  final DashboardInsights insights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = _PieCard(
      title: l10n.dashboardTopCategories,
      child: InfographicPie(
        rows: insights.topCategories
            .map((c) => PieRow(label: c.name, value: c.revenue))
            .toList(),
        palette: piePaletteA,
        formatValue: (v) => inr.format(v),
        subject: l10n.dashboardSubjectCategorySales,
        itemNoun: l10n.dashboardNounCategories,
      ),
    );

    final products = _PieCard(
      title: l10n.dashboardTopProducts,
      child: InfographicPie(
        rows: insights.topProducts
            .map((p) => PieRow(label: p.name, value: p.revenue))
            .toList(),
        palette: piePaletteB,
        formatValue: (v) => inr.format(v),
        subject: l10n.dashboardSubjectProductSales,
        itemNoun: l10n.dashboardNounProducts,
      ),
    );

    final slowMovers = _PieCard(
      title: l10n.dashboardSlowMovers,
      hint: l10n.dashboardSlowMoversHint,
      child: InfographicPie(
        rows: insights.slowMovers
            .map((m) => PieRow(label: m.name, value: m.stock))
            .toList(),
        palette: piePaletteC,
        formatValue: (v) => l10n.dashboardUnitsValue(v.toStringAsFixed(0)),
        subject: l10n.dashboardSubjectIdleStock,
        itemNoun: l10n.dashboardNounProducts,
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= Bp.xl) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: categories),
                  const SizedBox(width: AppSizes.md),
                  Expanded(child: products),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              slowMovers,
            ],
          );
        }
        return Column(
          children: [
            categories,
            const SizedBox(height: AppSizes.md),
            products,
            const SizedBox(height: AppSizes.md),
            slowMovers,
          ],
        );
      },
    );
  }
}

class _PieCard extends StatelessWidget {
  const _PieCard({required this.title, required this.child, this.hint});
  final String title;
  final String? hint;
  final Widget child;

  void _expand(BuildContext context) {
    AppHaptics.selection();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            _ExpandedChartPage(title: title, hint: hint, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(title)),
              _ExpandButton(
                tooltip: l10n.dashboardExpandChart,
                onTap: () => _expand(context),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(hint!, style: DashText.bodySm),
          ],
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.tooltip, required this.onTap});
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xxs),
          child: AppIcon(
            AppIcons.expandRounded,
            size: AppSizes.iconSm,
            color: AppColors.subtle,
          ),
        ),
      ),
    );
  }
}

class _ExpandedChartPage extends StatelessWidget {
  const _ExpandedChartPage({
    required this.title,
    required this.hint,
    required this.child,
  });
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: title),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          FloatingAppBar.contentTopInset(context) + AppSizes.md,
          AppSizes.lg,
          AppSizes.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hint != null) ...[
              Text(hint!, style: DashText.bodySm),
              const SizedBox(height: AppSizes.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
