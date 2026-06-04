import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_caution_page.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_invoices_page.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_quotations_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_divider.dart';

/// The per-shop landing for a customer. Every record the shop keeps for them —
/// invoices, caution deposit, quotations — is a first-class section here, so
/// nothing is buried behind a conditional banner. Vendors see only invoices.
class ShopSectionsPage extends StatefulWidget {
  const ShopSectionsPage({super.key, required this.shop});
  final LinkedShop shop;

  @override
  State<ShopSectionsPage> createState() => _ShopSectionsPageState();
}

class _ShopSectionsPageState extends State<ShopSectionsPage> {
  bool get _isParty => widget.shop.role == ShopRole.party;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    final p = context.read<ShopsProvider>();
    return Future.wait([
      p.loadInvoices(widget.shop),
      if (_isParty) p.loadCaution(widget.shop),
      if (_isParty) p.loadQuotations(widget.shop),
    ]);
  }

  String _moneyShort(double v) =>
      '${AppStrings.currencySymbol}${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ShopsProvider>();

    final invoices = p.invoicesFor(widget.shop);
    final invoiceCount = invoices?.length ?? widget.shop.invoiceCount;

    final caution = _isParty ? p.cautionFor(widget.shop) : null;
    final quotes = _isParty
        ? (p.quotationsFor(widget.shop) ?? const <ShopQuotation>[])
        : const <ShopQuotation>[];
    final pendingQuotes = quotes.where((q) => q.isPending).length;

    final rows = <Widget>[
      _SectionRow(
        icon: Icons.receipt_long_rounded,
        accent: AppColors.brand,
        title: 'Invoices',
        subtitle: invoiceCount == 0
            ? 'No invoices yet'
            : '$invoiceCount invoice${invoiceCount == 1 ? '' : 's'}',
        onTap: () => _open(ShopInvoicesPage(shop: widget.shop)),
      ),
      if (_isParty) ...[
        _SectionRow(
          icon: Icons.savings_rounded,
          accent: AppColors.success,
          title: AppStrings.cautionTitle,
          subtitle: caution == null
              ? 'View deposit & history'
              : '${_moneyShort(caution.balance)} held by shop',
          onTap: () => _open(ShopCautionPage(shop: widget.shop)),
        ),
        _SectionRow(
          icon: Icons.request_quote_rounded,
          accent: AppColors.accentIndigo,
          title: 'Quotations',
          subtitle: quotes.isEmpty
              ? 'No quotations yet'
              : pendingQuotes > 0
                  ? '$pendingQuotes awaiting you · ${quotes.length} total'
                  : '${quotes.length} quotation${quotes.length == 1 ? '' : 's'}',
          badge: pendingQuotes > 0 ? '$pendingQuotes' : null,
          onTap: () => _open(ShopQuotationsPage(shop: widget.shop)),
        ),
      ],
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.shop.shopName ?? widget.shop.name)),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
          children: [
            const AppDivider.flush(),
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0) const AppDivider.inset(leading: 60),
              rows[i],
            ],
            const AppDivider.flush(),
          ],
        ),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: AppSizes.iconLg),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm, vertical: AppSizes.xs),
                  decoration: ShapeDecoration(
                    color: AppColors.accentIndigo,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: Text(badge!,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: AppSizes.sm),
              ],
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      );
  }
}
