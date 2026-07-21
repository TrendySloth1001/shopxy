import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/features/orders/presentation/services/invoice_share.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart'
    show CancelOrderException;
import 'package:shopxy_customer/features/payments/razorpay_checkout.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/orders/presentation/widgets/order_timeline.dart';
import 'package:shopxy_customer/features/returns/presentation/widgets/request_return_sheet.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_invoice_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_dialog.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

/// Customer-facing order detail. One parent CustomerOrder = one
/// checkout submission; per-vendor slices live as sections inside.
///
/// Visual model: a single white sheet split into divider-bounded
/// sections (no floating cards) for a formal, statement-like read.
/// Layout, top to bottom:
///   1. Delivery snapshot (address as captured at place time)
///   2. One section per vendor (shop + status + items + invoice/cancel)
///   3. Buy again
///   4. Order summary (items total / delivery / grand total)
///   5. Customer's note, if present
/// The online-payment call-to-action is pinned to a sticky bottom bar
/// rather than living inline at the top.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final int orderId;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  CustomerOrderDetail? _order;
  bool _loading = true;
  String? _error;

  /// Tracks which child id is mid-cancel so the right button shows the
  /// spinner — multiple shops can be cancelled in sequence.
  int? _cancellingChildId;

  /// Tracks which child id is mid-download so the right invoice icon
  /// can render a spinner.
  int? _downloadingChildId;

  /// In-flight reorder request — disables the "Buy again" button to
  /// avoid double-submission.
  bool _reordering = false;

  /// In-flight online payment — drives the Pay Now spinner.
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await context.read<OrdersProvider>().loadDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = o;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  /// Resume/complete the online payment for this order. Opens the Razorpay
  /// sheet for the payable remainder, then reloads so the new paymentStatus
  /// (PAID, set by the backend webhook) is reflected.
  Future<void> _payNow() async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final cart = context.read<CartProvider>();
      final checkout = await cart.payForOrder(widget.orderId);
      final result = await RazorpayCheckout().open(
        clientParams: checkout.clientParams,
        description: 'Order #${widget.orderId}',
      );
      String? syncedStatus;
      if (result.isSuccess) {
        // Webhook can't reach localhost (and may lag in prod): confirm with the
        // server now so the order flips to PAID immediately. Best-effort.
        try {
          syncedStatus = await cart.syncOrderPayment(widget.orderId);
        } catch (_) {
          /* non-fatal — the reload below still reflects server state */
        }
      }
      if (!mounted) return;
      if (result.isSuccess) {
        // Sheet succeeded but the server hasn't confirmed yet (webhook
        // lag / sync miss) — that's normal, not an error.
        final confirmed = syncedStatus == 'PAID';
        showAppSnackbar(
          context,
          message: confirmed
              ? 'Payment successful'
              : 'Payment received — being confirmed. This can take a minute.',
          tone: confirmed ? AppSnackbarTone.success : AppSnackbarTone.info,
        );
      } else if (result.outcome == RazorpayOutcome.dismissed) {
        // The customer closed the sheet — nothing was charged. Calm copy
        // that points at the retry path instead of an error tone.
        showAppSnackbar(
          context,
          message:
              'Payment not completed — nothing was charged. Tap "Pay Now" whenever you\'re ready.',
          tone: AppSnackbarTone.info,
        );
      } else {
        showAppSnackbar(
          context,
          message:
              '${result.message ?? 'Payment failed'} — you can retry with "Pay Now".',
          tone: AppSnackbarTone.error,
        );
      }
    } catch (e) {
      if (mounted) {
        // The backend returns ALREADY_PAID (409) when a prior attempt already
        // paid this order — reopening the sheet on a paid order is exactly what
        // froze Razorpay. Surface it as success-ish, not a scary error; the
        // reload below will drop the Pay button.
        final msg = e.toString();
        final alreadyPaid =
            msg.contains('ALREADY_PAID') || msg.contains('already paid');
        showAppSnackbar(
          context,
          message: alreadyPaid
              ? 'This order is already paid'
              : 'Could not start payment: ${friendlyError(e)}',
          tone: alreadyPaid ? AppSnackbarTone.info : AppSnackbarTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
      // Webhook may land a beat after the sheet closes — reload either way.
      await _load();
    }
  }

  Future<void> _downloadInvoice(ShopOrderDetail child) async {
    final invoice = child.invoice;
    if (invoice == null) return;
    setState(() => _downloadingChildId = child.id);
    try {
      final token = context.read<TokenManager>().accessToken;
      if (token == null) {
        throw Exception('Please sign in to download invoices.');
      }
      final bytes = await context.read<OrdersProvider>().downloadInvoicePdf(
        parentId: widget.orderId,
        childId: child.id,
        accessToken: token,
      );
      if (!mounted) return;
      await shareInvoicePdf(
        context: context,
        invoiceNo: invoice.invoiceNo,
        bytes: bytes,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: friendlyError(e, fallback: 'Could not download the invoice.'),
        tone: AppSnackbarTone.error,
      );
    } finally {
      if (mounted) setState(() => _downloadingChildId = null);
    }
  }

  Future<void> _reorder() async {
    setState(() => _reordering = true);
    try {
      final result = await context.read<OrdersProvider>().reorder(
        widget.orderId,
      );
      if (!mounted) return;
      if (result.items.isEmpty) {
        showAppSnackbar(
          context,
          message: 'None of the items are available right now',
          tone: AppSnackbarTone.error,
        );
        return;
      }
      final cart = context.read<CartProvider>();
      var actuallyAdded = 0;
      for (final item in result.items) {
        final r = cart.add(item.product, quantity: item.quantity);
        if (r != AddToCartResult.outOfStock) actuallyAdded += 1;
      }
      if (actuallyAdded == 0) {
        showAppSnackbar(
          context,
          message: 'These items are out of stock right now',
          tone: AppSnackbarTone.error,
        );
        return;
      }
      final addedCount = actuallyAdded;
      final skippedCount =
          result.skipped.length + (result.items.length - actuallyAdded);
      final msg = skippedCount == 0
          ? '$addedCount ${addedCount == 1 ? "item" : "items"} added to cart'
          : '$addedCount added · $skippedCount unavailable';
      showAppSnackbar(context, message: msg, tone: AppSnackbarTone.success);
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: friendlyError(e),
        tone: AppSnackbarTone.error,
      );
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Future<void> _cancelShop(ShopOrderDetail child) async {
    // Re-entry guard: the capsule only shows its spinner *after* the
    // confirm sheet resolves, so a double-tap on "Cancel items" could
    // otherwise stack two confirm sheets.
    if (_cancellingChildId != null) return;
    final sellerName = child.shop?.displayName ?? 'this seller';
    final ok = await AppConfirmSheet.show(
      context,
      title: 'Cancel items from $sellerName?',
      message: 'Items from other sellers in this order will continue.',
      confirmLabel: 'Cancel items',
      cancelLabel: 'Keep items',
      danger: true,
    );
    if (!ok || !mounted) return;

    setState(() => _cancellingChildId = child.id);
    try {
      await context.read<OrdersProvider>().cancelShopOrder(
        parentId: widget.orderId,
        childId: child.id,
      );
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'Items from ${child.shop?.displayName ?? "seller"} cancelled',
        tone: AppSnackbarTone.success,
      );
      await _load();
    } on CancelOrderException catch (e) {
      if (!mounted) return;
      if (e.code == 'NOT_CANCELLABLE') {
        // The slice crossed the shop's cancellation cut-off between our
        // last fetch and the tap — not an error on the customer's part.
        // Surface the server's explanation gently and refetch so the
        // now-stale Cancel button disappears.
        showAppSnackbar(
          context,
          message: e.message.isNotEmpty
              ? e.message
              : "This order has passed the shop's cancellation window.",
          tone: AppSnackbarTone.info,
        );
        await _load();
      } else {
        showAppSnackbar(
          context,
          message: e.message,
          tone: AppSnackbarTone.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: friendlyError(e),
        tone: AppSnackbarTone.error,
      );
    } finally {
      if (mounted) setState(() => _cancellingChildId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    // Place the "Placed on" date in the AppBar subtitle so the body
    // doesn't need a standalone card just to surface a timestamp —
    // Amazon/Flipkart do the same with their "Order placed on …" line.
    final subtitle = order == null
        ? null
        : DateFormat('d MMM y · h:mm a').format(order.createdAt);
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppAppBar(title: 'Order #${widget.orderId}', subtitle: subtitle),
      // Online-payment CTA is pinned to the bottom of the screen rather
      // than floating at the top of the scroll.
      bottomNavigationBar: (order != null && order.needsOnlinePayment)
          ? _PayNowBar(
              amount: order.payableRemainder,
              loading: _paying,
              onPay: _payNow,
            )
          : null,
      body: _loading
          ? const _OrderDetailSkeleton()
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.brand,
              child: _Body(
                order: order!,
                cancellingChildId: _cancellingChildId,
                downloadingChildId: _downloadingChildId,
                reordering: _reordering,
                onCancelShop: _cancelShop,
                onDownloadInvoice: _downloadInvoice,
                onReorder: _reorder,
                onReturnSubmitted: _load,
              ),
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.order,
    required this.cancellingChildId,
    required this.downloadingChildId,
    required this.reordering,
    required this.onCancelShop,
    required this.onDownloadInvoice,
    required this.onReorder,
    required this.onReturnSubmitted,
  });
  final CustomerOrderDetail order;
  final int? cancellingChildId;
  final int? downloadingChildId;
  final bool reordering;
  final Future<void> Function(ShopOrderDetail child) onCancelShop;
  final Future<void> Function(ShopOrderDetail child) onDownloadInvoice;
  final Future<void> Function() onReorder;
  final VoidCallback onReturnSubmitted;

  @override
  Widget build(BuildContext context) {
    final children = order.detailedShopOrders;
    final hasAddress =
        order.customerAddress != null && order.customerAddress!.isNotEmpty;
    final hasNote = order.note != null && order.note!.isNotEmpty;
    final reorderable = _anyReorderable(order);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.xl),
      children: [
        if (hasAddress) ...[
          const _SectionLabel(label: 'DELIVERING TO'),
          _DeliverySnapshotCard(order: order),
          const _SectionDivider(),
        ],
        // Heading only when the order genuinely splits — for a single
        // seller we just let the section itself speak. Mirrors how Amazon
        // and Flipkart treat a single-shipment order (no "Packages"
        // heading) vs a multi-shipment one ("Packages in this order").
        if (children.length > 1)
          _SectionLabel(
            label:
                '${children.length} PACKAGES · ${order.totalItemCount} '
                '${order.totalItemCount == 1 ? "ITEM" : "ITEMS"}',
          ),
        for (var i = 0; i < children.length; i++) ...[
          if (i != 0) const _SectionDivider(),
          _ShopOrderCard(
            child: children[i],
            cancelling: cancellingChildId == children[i].id,
            downloading: downloadingChildId == children[i].id,
            onCancel: () => onCancelShop(children[i]),
            onDownloadInvoice: () => onDownloadInvoice(children[i]),
            parentOrderId: order.id,
            onReturnSubmitted: onReturnSubmitted,
            packageIndex: children.length > 1 ? i + 1 : null,
            packageCount: children.length,
          ),
        ],
        const _SectionDivider(),
        if (reorderable) ...[
          _BuyAgainCard(loading: reordering, onPressed: onReorder),
          const _SectionDivider(),
        ],
        const _SectionLabel(label: 'ORDER SUMMARY'),
        _OrderSummaryCard(order: order),
        if (hasNote) ...[
          const _SectionDivider(),
          const _SectionLabel(label: 'YOUR NOTE'),
          _NoteCard(note: order.note!),
        ],
      ],
    );
  }
}

// ─── Section primitives ──────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Full-bleed hairline that separates one major section from the next.
/// In-section row breaks (between items) use indented dividers instead,
/// so the two read as distinct levels of the hierarchy.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.hairline);
}

/// Small soft-tinted capsule (pill) button for the per-section footer
/// actions — Cancel items (danger) / Request a return (brand). A tinted
/// fill with squircle-full corners reads as a deliberate button rather
/// than a bare text link, while staying lighter than a solid CTA.
class _CapsuleAction extends StatelessWidget {
  const _CapsuleAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
    this.loading = false,
  });

  final AppIconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: AppSizes.iconSm,
                  height: AppSizes.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                AppIcon(icon, size: AppSizes.iconSm, color: color),
              const SizedBox(width: AppSizes.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Aggregate status hero ───────────────────────────────────────────

/// Picks the (color, icon, headline) for the aggregate status row in
/// the Order Summary section.
({Color color, AppIconData icon, String headline, String? subtext})
_statusVisuals(CustomerOrder o) {
  final children = o.shopOrders;
  if (children.isEmpty) {
    return (
      color: AppColors.muted,
      icon: AppIcons.helpOutlineRounded,
      headline: 'No sellers',
      subtext: null,
    );
  }
  final confirmed = children.where((c) => c.isConfirmed).length;
  final pending = children.where((c) => c.isPending).length;
  final rejected = children.where((c) => c.isRejected).length;
  final cancelled = children.where((c) => c.isCancelled).length;
  final total = children.length;

  if (confirmed == total) {
    return (
      color: AppColors.success,
      icon: AppIcons.checkCircleOutlineRounded,
      headline: total == 1 ? 'Confirmed' : 'All sellers confirmed',
      subtext: null,
    );
  }
  if (cancelled == total) {
    return (
      color: AppColors.muted,
      icon: AppIcons.doDisturbAltRounded,
      headline: 'Cancelled',
      subtext: 'No charges apply',
    );
  }
  if (rejected == total) {
    return (
      color: AppColors.error,
      icon: AppIcons.cancelOutlined,
      headline: total == 1 ? 'Declined' : 'All sellers declined',
      subtext: null,
    );
  }
  if (pending == total) {
    return (
      color: AppColors.warning,
      icon: AppIcons.scheduleRounded,
      headline: total == 1 ? 'Waiting on seller' : 'Waiting on $total sellers',
      subtext: null,
    );
  }
  return (
    color: AppColors.warning,
    icon: AppIcons.hourglassBottomRounded,
    headline: '$confirmed of $total confirmed',
    subtext: o.aggregateStatusLabel,
  );
}

// ─── Delivery snapshot ───────────────────────────────────────────────

/// Address row with a compact one-line glimpse by default. Tapping
/// expands to reveal the full address + phone — keeps the hierarchy
/// quiet for the common case where the customer just wants to know the
/// order's destination at a glance.
class _DeliverySnapshotCard extends StatefulWidget {
  const _DeliverySnapshotCard({required this.order});
  final CustomerOrderDetail order;

  @override
  State<_DeliverySnapshotCard> createState() => _DeliverySnapshotCardState();
}

class _DeliverySnapshotCardState extends State<_DeliverySnapshotCard> {
  bool _expanded = false;

  /// First non-empty line of the address (street / locality) — what
  /// the merchant snapshot has at line 0.
  String _glimpse() {
    final addr = (widget.order.customerAddress ?? '').trim();
    if (addr.isEmpty) return '';
    final lines = addr
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    return lines.first;
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final fullAddr = (o.customerAddress ?? '').trim();
    final glimpse = _glimpse();
    final phone = o.customerPhone ?? '';

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.xs,
          AppSizes.lg,
          AppSizes.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: AppIcon(
                AppIcons.locationOnOutlined,
                color: AppColors.muted,
                size: AppSizes.iconMd,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (o.customerName.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            o.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.extraBold,
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          '·',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(width: AppSizes.sm),
                      ],
                      Expanded(
                        child: Text(
                          glimpse,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: AppDurations.short,
                    curve: Curves.easeOut,
                    alignment: Alignment.topLeft,
                    child: _expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: AppSizes.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (fullAddr.isNotEmpty)
                                  Text(
                                    fullAddr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppColors.black),
                                  ),
                                if (phone.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSizes.xs,
                                    ),
                                    child: Row(
                                      children: [
                                        const AppIcon(
                                          AppIcons.phoneRounded,
                                          size: AppSizes.iconSm,
                                          color: AppColors.muted,
                                        ),
                                        const SizedBox(width: AppSizes.xs),
                                        Text(
                                          phone,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.muted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: AppDurations.short,
              child: const AppIcon(
                AppIcons.expandMoreRounded,
                color: AppColors.subtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Buy again ───────────────────────────────────────────────────────

/// "Buy again" row at the foot of the order — repurchase a past order
/// in one tap. Only rendered when at least one shop in the order
/// produced an invoice (i.e. there's something to repeat).
class _BuyAgainCard extends StatelessWidget {
  const _BuyAgainCard({required this.loading, required this.onPressed});
  final bool loading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        children: [
          const AppIcon(
            AppIcons.replayCircleFilledRounded,
            color: AppColors.brand,
            size: AppSizes.iconXl,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buy again',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  'Adds the items from this order back to your cart',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          FilledButton(
            onPressed: loading ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.black,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              shape: AppShapes.squircle(AppSizes.radiusFull),
            ),
            child: loading
                ? const SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    'Add to cart',
                    style: Theme.of(context).textTheme.labelLarge?.extraBold,
                  ),
          ),
        ],
      ),
    );
  }
}

bool _anyReorderable(CustomerOrderDetail order) {
  for (final c in order.detailedShopOrders) {
    if (c.items.isNotEmpty &&
        (c.status == 'CONFIRMED' ||
            c.status == 'REJECTED' ||
            c.status == 'CANCELLED')) {
      return true;
    }
  }
  return false;
}

// ─── Per-vendor section ──────────────────────────────────────────────

class _ShopOrderCard extends StatelessWidget {
  const _ShopOrderCard({
    required this.child,
    required this.cancelling,
    required this.downloading,
    required this.onCancel,
    required this.onDownloadInvoice,
    required this.parentOrderId,
    required this.onReturnSubmitted,
    this.packageIndex,
    this.packageCount = 1,
  });
  final ShopOrderDetail child;
  final bool cancelling;
  final bool downloading;
  final VoidCallback onCancel;
  final VoidCallback onDownloadInvoice;
  final int parentOrderId;
  final VoidCallback onReturnSubmitted;

  /// 1-based package number when the order has multiple vendors. Null
  /// for single-vendor orders (the "Package 1 of 1" eyebrow is noise).
  final int? packageIndex;
  final int packageCount;

  /// One-liner shown when the Cancel button is absent but the slice is
  /// still mid-fulfilment — explains *why* using the shop's
  /// server-provided cancellation policy. Null when no note is needed
  /// (cancellable, already cancelled/rejected, or delivered).
  String? get _cancelUnavailableNote {
    if (child.canCancel) return null;
    if (child.status != 'CONFIRMED') return null;
    if (child.deliveredAt != null) return null;
    final why = switch (child.cancellationPolicy) {
      'UNTIL_CONFIRMED' =>
        'this shop accepts cancellations only until it confirms the order',
      'UNTIL_PACKED' =>
        'this shop accepts cancellations only until the order is packed',
      'UNTIL_SHIPPED' =>
        'this shop accepts cancellations only until the order is shipped',
      _ => "the shop's cancellation window has passed",
    };
    return 'This order can no longer be cancelled — $why.';
  }

  /// One-liner shown when the slice is delivered but Request-a-return is
  /// absent. Only covers the two cases we can explain with certainty
  /// (returns disabled / window elapsed); stays quiet otherwise — e.g.
  /// when a return was already filed — rather than guess wrong.
  String? get _returnUnavailableNote {
    if (child.canReturn) return null;
    if (child.status != 'CONFIRMED') return null;
    final deliveredAt = child.deliveredAt;
    if (deliveredAt == null) return null;
    final shop = child.shop;
    if (shop == null) return null;
    if (!shop.returnsEnabled) {
      return "This shop doesn't accept returns.";
    }
    final windowEnd = deliveredAt.add(Duration(days: shop.returnWindowDays));
    if (DateTime.now().isAfter(windowEnd)) {
      return 'The ${shop.returnWindowDays}-day return window for this order has closed.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final vendorName = child.shop?.displayName ?? 'Seller';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: "Package N of M" eyebrow (multi only) + status pill
        // on the right, then "Sold by X" as the title.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.md,
            AppSizes.lg,
            AppSizes.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (packageIndex != null)
                    Expanded(
                      child: Text(
                        'PACKAGE $packageIndex OF $packageCount',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  _StatusPill(status: child.status),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: AppIcon(
                      AppIcons.storefrontOutlined,
                      size: AppSizes.iconSm,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          const TextSpan(text: 'Sold by '),
                          TextSpan(
                            text: vendorName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.black,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(
          height: 1,
          color: AppColors.hairline,
          indent: AppSizes.lg,
          endIndent: AppSizes.lg,
        ),
        // Items
        for (var i = 0; i < child.items.length; i++) ...[
          _ItemRow(item: child.items[i]),
          if (i != child.items.length - 1)
            const Divider(
              height: 1,
              color: AppColors.hairline,
              indent: AppSizes.lg,
              endIndent: AppSizes.lg,
            ),
        ],
        // Tracking timeline — only when the slice has been confirmed or
        // has any post-confirmation milestone. Hiding it for raw PENDING
        // rows avoids a "Order placed → empty" strip that just repeats
        // the header timestamp.
        if (child.events.isNotEmpty &&
            child.status != 'PENDING' &&
            child.status != 'REJECTED' &&
            child.status != 'CANCELLED') ...[
          const Divider(
            height: 1,
            color: AppColors.hairline,
            indent: AppSizes.lg,
            endIndent: AppSizes.lg,
          ),
          OrderTimeline(events: child.events, status: child.status),
        ],
        // Footer slot: invoice link (confirmed) / rejection note /
        // cancel link (pending). Only one of these renders at a time.
        if (child.invoice != null)
          _InvoiceFooter(
            invoice: child.invoice!,
            linkedPartyId: child.linkedPartyId,
            shopName: child.shop?.displayName,
            downloading: downloading,
            onDownload: onDownloadInvoice,
          ),
        if (child.isRejected &&
            child.decisionNote != null &&
            child.decisionNote!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.sm,
              AppSizes.lg,
              AppSizes.md,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: ShapeDecoration(
                color: AppColors.errorSoft,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIcon(
                    AppIcons.infoOutlineRounded,
                    size: AppSizes.iconSm,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      child.decisionNote!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // "Cancel items" — gated purely on the server-computed flag
        // (PENDING always; CONFIRMED until the shop's cancellation-
        // policy cut-off). No client-side status derivation: when the
        // flag is false and the slice is mid-fulfilment, no action
        // renders at all.
        if (child.canCancel)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.xs,
                AppSizes.lg,
                AppSizes.md,
              ),
              child: _CapsuleAction(
                icon: AppIcons.closeRounded,
                label: 'Cancel items',
                color: AppColors.error,
                background: AppColors.errorSoft,
                loading: cancelling,
                onTap: onCancel,
              ),
            ),
          ),
        // "Request return" — gated purely on the server-computed flag:
        // CONFIRMED + a DELIVERED event + returns enabled + within the
        // shop's return window. The server is the source of truth.
        if (child.canReturn && child.items.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.xs,
                AppSizes.lg,
                AppSizes.md,
              ),
              child: _CapsuleAction(
                icon: AppIcons.assignmentReturnOutlined,
                label: 'Request a return',
                color: AppColors.brand,
                background: AppColors.brandSoft,
                onTap: () => openRequestReturn(
                  context,
                  parentOrderId: parentOrderId,
                  shopOrder: child,
                  onSubmitted: onReturnSubmitted,
                ),
              ),
            ),
          ),
        // When an action is absent but the customer would reasonably
        // look for it, say why in one quiet line instead of leaving a
        // silent gap. Still no client-side eligibility derivation — we
        // only ever explain a server-computed `false`.
        if (_cancelUnavailableNote != null)
          _ActionUnavailableNote(text: _cancelUnavailableNote!),
        if (_returnUnavailableNote != null)
          _ActionUnavailableNote(text: _returnUnavailableNote!),
      ],
    );
  }
}

/// Muted single-line footnote under a vendor section explaining why a
/// cancel/return action isn't offered.
class _ActionUnavailableNote extends StatelessWidget {
  const _ActionUnavailableNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(
            AppIcons.infoOutlineRounded,
            size: AppSizes.iconSm,
            color: AppColors.muted,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.muted,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer line under the items list when this vendor's slice has been
/// invoiced. Surfaces three states (PAID green / PARTIALLY_PAID amber /
/// UNPAID muted) and is tappable when [linkedPartyId] is set — taking
/// the customer to the full invoice view at this seller's shop. We can
/// only open the viewer once the customer is *linked* as a Party at
/// the seller's shop (the per-party invoice route is auth-scoped that
/// way); for unlinked rows the row stays as a non-interactive line.
class _InvoiceFooter extends StatelessWidget {
  const _InvoiceFooter({
    required this.invoice,
    required this.linkedPartyId,
    required this.shopName,
    required this.downloading,
    required this.onDownload,
  });
  final OrderInvoiceRef invoice;
  final int? linkedPartyId;
  final String? shopName;
  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final (color, label) = _visuals();
    final canOpen = linkedPartyId != null;

    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        children: [
          AppIcon(
            invoice.isPaid
                ? AppIcons.verifiedRounded
                : AppIcons.receiptLongOutlined,
            size: AppSizes.iconSm,
            color: color,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Download invoice',
            onPressed: downloading ? null : onDownload,
            iconSize: AppSizes.iconMd,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: AppSizes.iconXl,
              minHeight: AppSizes.iconXl,
            ),
            icon: downloading
                ? const SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : AppIcon(AppIcons.downloadRounded, color: color),
          ),
          if (canOpen)
            AppIcon(
              AppIcons.chevronRightRounded,
              size: AppSizes.iconMd,
              color: color,
            ),
        ],
      ),
    );

    if (!canOpen) return content;

    return InkWell(onTap: () => _openInvoice(context), child: content);
  }

  void _openInvoice(BuildContext context) {
    final partyId = linkedPartyId!;
    final shop = LinkedShop(
      id: partyId,
      role: ShopRole.party,
      name: shopName ?? 'Shop',
      email: null,
      phone: null,
      address: null,
      invoiceCount: 0,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ShopInvoiceDetailPage(shop: shop, invoiceId: invoice.id),
      ),
    );
  }

  (Color, String) _visuals() {
    if (invoice.isPaid) {
      return (AppColors.success, 'Paid · Invoice ${invoice.invoiceNo}');
    }
    if (invoice.isPartiallyPaid) {
      return (
        AppColors.warning,
        '${AppFormat.rupees(invoice.paidAmount)} of '
            '${AppFormat.rupees(invoice.total)} paid · '
            'Invoice ${invoice.invoiceNo}',
      );
    }
    return (AppColors.muted, 'Invoice ${invoice.invoiceNo} · payment pending');
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = _visuals(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 3),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static (String, Color, Color) _visuals(String status) {
    switch (status) {
      case 'CONFIRMED':
        return ('CONFIRMED', AppColors.success, AppColors.successSoft);
      case 'REJECTED':
        return ('DECLINED', AppColors.error, AppColors.errorSoft);
      case 'CANCELLED':
        return ('CANCELLED', AppColors.muted, AppColors.surfaceTint);
      default:
        return ('PENDING', AppColors.warning, AppColors.warningSoft);
    }
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final CustomerOrderItem item;

  static String _qty(double q) =>
      q.truncateToDouble() == q ? q.toInt().toString() : q.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(productId: item.productId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
              child: Container(
                width: AppSizes.avatarMd,
                height: AppSizes.avatarMd,
                color: AppColors.heroPanel,
                child: item.imageUrl == null
                    ? const AppIcon(
                        AppIcons.imageOutlined,
                        color: AppColors.muted,
                        size: AppSizes.iconMd,
                      )
                    : NetworkImageBox(url: resolveImageUrl(item.imageUrl!)),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm,
                          vertical: 2,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.heroPanel,
                          shape: AppShapes.squircle(AppSizes.radiusFull),
                        ),
                        child: Text(
                          'Qty ${_qty(item.quantity)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Text(
                        item.unit,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${AppFormat.rupeesSmart(item.unitPrice)} each',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            AppPriceText.precise(
              item.total,
              fontWeight: FontWeight.w800,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Order-wide bill summary ─────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});
  final CustomerOrderDetail order;

  @override
  Widget build(BuildContext context) {
    // Prefer the sum of confirmed invoice totals when at least one shop
    // has been invoiced — that's the authoritative number the customer
    // will pay. Otherwise show the estimated cart total.
    double total = 0;
    bool usedInvoices = false;
    for (final c in order.detailedShopOrders) {
      if (c.invoice != null) {
        total += c.invoice!.total;
        usedInvoices = true;
      } else if (!c.isCancelled && !c.isRejected) {
        total += c.estimatedTotal;
      }
    }
    final status = _statusVisuals(order);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row at the top of the summary — icon + headline +
          // small subtext on a single line, matching the bill-row rhythm.
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: Row(
              children: [
                AppIcon(
                  status.icon,
                  color: status.color,
                  size: AppSizes.iconSm,
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    status.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: status.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (status.subtext != null)
                  Text(
                    status.subtext!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: status.color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: AppSizes.sm),
          _BillRow(label: 'Items total', value: total),
          const _BillRow(
            label: 'Delivery',
            valueLabel: 'FREE',
            valueColor: AppColors.success,
          ),
          const Divider(height: AppSizes.lg, color: AppColors.hairline),
          _BillRow(
            label: usedInvoices ? AppStrings.finalTotal : 'Total payable',
            value: total,
            bold: true,
            valueColor: usedInvoices ? AppColors.success : null,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            usedInvoices
                ? 'Confirmed totals from the shops\' invoices.'
                : 'The shops will confirm the final amount when they accept your order.',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    this.value,
    this.valueLabel,
    this.valueColor,
    this.bold = false,
  });
  final String label;
  final double? value;
  final String? valueLabel;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final col = valueColor ?? AppColors.black;
    final theme = Theme.of(context);
    final Widget val;
    if (valueLabel != null) {
      val = Text(
        valueLabel!,
        style: (bold ? theme.textTheme.bodyLarge : theme.textTheme.bodyMedium)
            ?.copyWith(color: col, fontWeight: FontWeight.w800),
      );
    } else {
      val = AppPriceText.precise(
        value ?? 0,
        color: col,
        fontWeight: FontWeight.w800,
        style: TextStyle(fontSize: bold ? 16 : 13),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: bold ? AppColors.black : AppColors.muted,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          val,
        ],
      ),
    );
  }
}

// ─── Note ────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  final String note;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Text(
        note,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.black, height: 1.5),
      ),
    );
  }
}

// ─── Skeleton loading state ──────────────────────────────────────────

/// Full-page skeleton that mirrors the real order-detail layout while
/// the API call is in flight. Rendered as a non-scrolling ListView so
/// the layout proportions match exactly what appears once data loads.
class _OrderDetailSkeleton extends StatelessWidget {
  const _OrderDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.xl),
      children: const [
        // ── Delivering to section ──────────────────────────────────
        _SkeletonSectionLabel(),
        _DeliveryAddressSkeleton(),
        _SectionDivider(),
        // ── Vendor package section (2 packages) ───────────────────
        _ShopOrderSkeleton(),
        _SectionDivider(),
        _ShopOrderSkeleton(),
        _SectionDivider(),
        // ── Order summary section ──────────────────────────────────
        _SkeletonSectionLabel(),
        _OrderSummarySkeleton(),
      ],
    );
  }
}

/// Skeleton for the "DELIVERING TO" / "ORDER SUMMARY" section label.
class _SkeletonSectionLabel extends StatelessWidget {
  const _SkeletonSectionLabel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: AppShimmerLine(widthFactor: 0.3, height: 12),
    );
  }
}

/// Skeleton for the delivery-address row: location icon + customer-name
/// line + address snippet line.
class _DeliveryAddressSkeleton extends StatelessWidget {
  const _DeliveryAddressSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location icon placeholder
          AppShimmerBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer name
                AppShimmerLine(widthFactor: 0.45, height: 14),
                SizedBox(height: AppSizes.xs),
                // Address snippet
                AppShimmerLine(widthFactor: 0.7, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for one vendor-package section:
///   - status pill + "Sold by" row
///   - 3 item rows (thumbnail + name line + qty/price line)
class _ShopOrderSkeleton extends StatelessWidget {
  const _ShopOrderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: status pill on the right + "Sold by" row
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.md,
            AppSizes.lg,
            AppSizes.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Spacer(),
                  // Status pill
                  AppShimmerBox(
                    width: 72,
                    height: 20,
                    radius: AppSizes.radiusFull,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Storefront icon
                  AppShimmerBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    radius: AppSizes.radiusXs,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  // "Sold by <name>"
                  const AppShimmerLine(widthFactor: 0.5, height: 14),
                ],
              ),
            ],
          ),
        ),
        const Divider(
          height: 1,
          color: AppColors.hairline,
          indent: AppSizes.lg,
          endIndent: AppSizes.lg,
        ),
        // 3 item rows
        const _ItemRowSkeleton(),
        const Divider(
          height: 1,
          color: AppColors.hairline,
          indent: AppSizes.lg,
          endIndent: AppSizes.lg,
        ),
        const _ItemRowSkeleton(),
        const Divider(
          height: 1,
          color: AppColors.hairline,
          indent: AppSizes.lg,
          endIndent: AppSizes.lg,
        ),
        const _ItemRowSkeleton(),
      ],
    );
  }
}

/// Skeleton for a single item row: image thumbnail + two text lines +
/// price block on the trailing edge.
class _ItemRowSkeleton extends StatelessWidget {
  const _ItemRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product thumbnail
          AppShimmerBox(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name
                AppShimmerLine(widthFactor: 0.8, height: 14),
                SizedBox(height: AppSizes.xs),
                // Qty / unit / price line
                AppShimmerLine(widthFactor: 0.55, height: 11),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Price on trailing edge
          const AppShimmerLine(widthFactor: 0.15, height: 13),
        ],
      ),
    );
  }
}

/// Skeleton for the order-summary section:
///   - status icon + headline
///   - 3 bill rows (items total, delivery, grand total)
class _OrderSummarySkeleton extends StatelessWidget {
  const _OrderSummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row: icon + headline
          Row(
            children: [
              AppShimmerBox(
                width: AppSizes.iconSm,
                height: AppSizes.iconSm,
                radius: AppSizes.radiusXs,
              ),
              const SizedBox(width: AppSizes.sm),
              const AppShimmerLine(widthFactor: 0.4, height: 14),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: AppSizes.sm),
          // Bill row: items total
          const _BillRowSkeleton(labelFactor: 0.35, valueFactor: 0.2),
          const SizedBox(height: 6),
          // Bill row: delivery
          const _BillRowSkeleton(labelFactor: 0.25, valueFactor: 0.15),
          const Divider(height: AppSizes.lg, color: AppColors.hairline),
          // Bill row: grand total (slightly taller)
          const _BillRowSkeleton(labelFactor: 0.4, valueFactor: 0.25),
        ],
      ),
    );
  }
}

/// One bill-row skeleton with a label on the left and a value on the
/// right, sized by [labelFactor] / [valueFactor] of parent width.
class _BillRowSkeleton extends StatelessWidget {
  const _BillRowSkeleton({
    required this.labelFactor,
    required this.valueFactor,
  });

  final double labelFactor;
  final double valueFactor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppShimmerLine(widthFactor: labelFactor, height: 13)),
        AppShimmerLine(widthFactor: valueFactor, height: 13),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              AppIcons.cloudOffRounded,
              size: AppSizes.iconHuge,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              AppStrings.somethingWentWrong,
              style: Theme.of(context).textTheme.titleMedium?.extraBold,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.lg),
            AppButton.secondary(
              label: AppStrings.tryAgain,
              icon: AppIcons.refreshRounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pay-now bottom bar ──────────────────────────────────────────────

/// Sticky bottom action bar shown on an order whose online payment is
/// still pending or previously failed. Outstanding amount on the left,
/// Pay Now on the right, separated from the body by a top hairline.
/// Tapping Pay Now re-opens the Razorpay sheet for the payable remainder.
class _PayNowBar extends StatelessWidget {
  const _PayNowBar({
    required this.amount,
    required this.loading,
    required this.onPay,
  });

  final double amount;
  final bool loading;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.md,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment pending',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      AppFormat.rupeesPrecise(amount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              AppButton(
                label: 'Pay Now',
                isLoading: loading,
                onPressed: loading ? null : onPay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
