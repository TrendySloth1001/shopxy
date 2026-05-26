import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/features/orders/presentation/services/invoice_share.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/orders/presentation/widgets/order_timeline.dart';
import 'package:shopxy_customer/features/returns/presentation/widgets/request_return_sheet.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_invoice_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_dialog.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Customer-facing order detail. One parent CustomerOrder = one
/// checkout submission; per-vendor slices live as cards inside.
///
/// Layout, top to bottom:
///   1. Aggregate status hero (e.g. "2 of 3 shops confirmed")
///   2. Delivery snapshot (address as captured at place time)
///   3. One card per vendor with:
///        • shop chip + status pill
///        • items list
///        • shop subtotal + invoice ref when confirmed
///        • per-shop cancel button while still PENDING
///   4. Order summary (items total / delivery / grand total)
///   5. Customer's note, if present
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
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _downloadInvoice(ShopOrderDetail child) async {
    final invoice = child.invoice;
    if (invoice == null) return;
    setState(() => _downloadingChildId = child.id);
    try {
      final ds = context.read<OrdersRemoteDataSource>();
      final token = context.read<TokenManager>().accessToken;
      if (token == null) {
        throw Exception('Please sign in to download invoices.');
      }
      final bytes = await ds.downloadInvoicePdf(
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
        message: e.toString().replaceFirst('Exception: ', ''),
        tone: AppSnackbarTone.error,
      );
    } finally {
      if (mounted) setState(() => _downloadingChildId = null);
    }
  }

  Future<void> _reorder() async {
    setState(() => _reordering = true);
    try {
      final ds = context.read<OrdersRemoteDataSource>();
      final result = await ds.reorder(widget.orderId);
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
      showAppSnackbar(
        context,
        message: msg,
        tone: AppSnackbarTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        tone: AppSnackbarTone.error,
      );
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Future<void> _cancelShop(ShopOrderDetail child) async {
    final sellerName = child.shop?.displayName ?? 'this seller';
    final ok = await AppConfirmDialog.show(
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
      showAppSnackbar(
        context,
        message: e.message,
        tone: AppSnackbarTone.error,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
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
      backgroundColor: AppColors.canvas,
      appBar: AppAppBar(
        title: 'Order #${widget.orderId}',
        subtitle: subtitle,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        if (order.customerAddress != null &&
            order.customerAddress!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          const _SectionLabel(label: 'DELIVERING TO'),
          _DeliverySnapshotCard(order: order),
        ],
        const SizedBox(height: AppSizes.lg),
        // Heading only when the order genuinely splits — for a single
        // seller we just let the card itself speak. Mirrors how Amazon
        // and Flipkart treat a single-shipment order (no "Packages"
        // heading) vs a multi-shipment one ("Packages in this order").
        if (children.length > 1)
          _SectionLabel(
            label:
                '${children.length} PACKAGES · ${order.totalItemCount} '
                '${order.totalItemCount == 1 ? "ITEM" : "ITEMS"}',
          ),
        for (var i = 0; i < children.length; i++) ...[
          if (i != 0) const SizedBox(height: AppSizes.md),
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
        if (_anyReorderable(order)) ...[
          const SizedBox(height: AppSizes.lg),
          _BuyAgainCard(loading: reordering, onPressed: onReorder),
        ],
        const SizedBox(height: AppSizes.lg),
        const _SectionLabel(label: 'ORDER SUMMARY'),
        _OrderSummaryCard(order: order),
        if (order.note != null && order.note!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.lg),
          const _SectionLabel(label: 'YOUR NOTE'),
          _NoteCard(note: order.note!),
        ],
      ],
    );
  }
}

// ─── Section primitive ───────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg, AppSizes.xs, AppSizes.lg, AppSizes.sm,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─── Aggregate status hero ───────────────────────────────────────────

/// Picks the (color, icon, headline) for the aggregate status row in
/// the Order Summary card. The old top-of-page status hero was
/// removed in favour of a single inline row — same information, much
/// less visual weight.
({Color color, IconData icon, String headline, String? subtext}) _statusVisuals(
    CustomerOrder o) {
  final children = o.shopOrders;
  if (children.isEmpty) {
    return (
      color: AppColors.muted,
      icon: Icons.help_outline_rounded,
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
      icon: Icons.check_circle_outline_rounded,
      headline: total == 1 ? 'Confirmed' : 'All sellers confirmed',
      subtext: null,
    );
  }
  if (cancelled == total) {
    return (
      color: AppColors.muted,
      icon: Icons.do_disturb_alt_rounded,
      headline: 'Cancelled',
      subtext: 'No charges apply',
    );
  }
  if (rejected == total) {
    return (
      color: AppColors.error,
      icon: Icons.cancel_outlined,
      headline: total == 1 ? 'Declined' : 'All sellers declined',
      subtext: null,
    );
  }
  if (pending == total) {
    return (
      color: AppColors.warning,
      icon: Icons.schedule_rounded,
      headline: total == 1
          ? 'Waiting on seller'
          : 'Waiting on $total sellers',
      subtext: null,
    );
  }
  return (
    color: AppColors.warning,
    icon: Icons.hourglass_bottom_rounded,
    headline: '$confirmed of $total confirmed',
    subtext: o.aggregateStatusLabel,
  );
}

// ─── Delivery snapshot ───────────────────────────────────────────────

/// Address card with a compact one-line glimpse by default. Tapping
/// the card expands to reveal the full address + phone — keeps the
/// hierarchy quiet for the common case where the customer just wants
/// to know the order's destination at a glance.
class _DeliverySnapshotCard extends StatefulWidget {
  const _DeliverySnapshotCard({required this.order});
  final CustomerOrderDetail order;

  @override
  State<_DeliverySnapshotCard> createState() => _DeliverySnapshotCardState();
}

class _DeliverySnapshotCardState extends State<_DeliverySnapshotCard> {
  bool _expanded = false;

  /// First non-empty line of the address (street / locality) — what
  /// the merchant snapshot has at line 0. We pair it with the city
  /// segment when the first line is too short to be useful on its
  /// own.
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

    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(AppSizes.radiusMd),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on_outlined,
                    color: AppColors.muted, size: 18),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '·',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            glimpse,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.topLeft,
                      child: _expanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (fullAddr.isNotEmpty)
                                    Text(
                                      fullAddr,
                                      style: const TextStyle(
                                        color: AppColors.black,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  if (phone.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_rounded,
                                              size: 14,
                                              color: AppColors.muted),
                                          const SizedBox(width: 4),
                                          Text(
                                            phone,
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 12,
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
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.expand_more_rounded,
                    color: AppColors.subtle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Per-vendor card ─────────────────────────────────────────────────

/// Big primary call-to-action card at the bottom of the order detail
/// — wraps the "Buy again" button so the user can repurchase a past
/// order in one tap. Only rendered when at least one shop in the
/// order produced an invoice (i.e. there's something to repeat).
class _BuyAgainCard extends StatelessWidget {
  const _BuyAgainCard({required this.loading, required this.onPressed});
  final bool loading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              const Icon(Icons.replay_circle_filled_rounded,
                  color: AppColors.brand, size: 28),
              const SizedBox(width: AppSizes.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buy again',
                      style: TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Adds the items from this order back to your cart',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
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
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add to cart',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final vendorName = child.shop?.displayName ?? 'Seller';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "Package N of M" eyebrow (multi only) + status pill
          // on the right, then "Sold by X" as the title — same pattern
          // Amazon/Flipkart use to ground each shipment in the order.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm,
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
                          style: const TextStyle(
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
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.storefront_outlined,
                          size: 16, color: AppColors.muted),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            const TextSpan(text: 'Sold by '),
                            TextSpan(
                              text: vendorName,
                              style: const TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
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
            indent: AppSizes.md,
            endIndent: AppSizes.md,
          ),
          // Items
          for (var i = 0; i < child.items.length; i++) ...[
            _ItemRow(item: child.items[i]),
            if (i != child.items.length - 1)
              const Divider(
                height: 1,
                color: AppColors.hairline,
                indent: AppSizes.md,
                endIndent: AppSizes.md,
              ),
          ],
          // Tracking timeline — only when the slice has been
          // confirmed or has any post-confirmation milestone. Hiding
          // it for raw PENDING rows avoids a "Order placed → empty"
          // strip that just repeats the header timestamp.
          if (child.events.isNotEmpty &&
              child.status != 'PENDING' &&
              child.status != 'REJECTED' &&
              child.status != 'CANCELLED') ...[
            const Divider(
              height: 1,
              color: AppColors.hairline,
              indent: AppSizes.md,
              endIndent: AppSizes.md,
            ),
            OrderTimeline(events: child.events, status: child.status),
          ],
          // Footer slot: invoice link (confirmed) / rejection note /
          // cancel link (pending). Only one of these renders at a time,
          // so we don't accumulate vertical padding when nothing is
          // there to say.
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
                AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.md,
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
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        child.decisionNote!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (child.isPending)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: cancelling ? null : onCancel,
                icon: cancelling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel items'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md, vertical: 6),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          // "Request return" — surfaces once the slice has been
          // confirmed (an invoice exists) AND the merchant's return
          // policy allows it. Eligibility window is enforced server-side.
          if (child.status == 'CONFIRMED' &&
              child.items.isNotEmpty &&
              (child.shop?.returnsEnabled ?? true))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => openRequestReturn(
                  context,
                  parentOrderId: parentOrderId,
                  shopOrder: child,
                  onSubmitted: onReturnSubmitted,
                ),
                icon: const Icon(Icons.assignment_return_outlined, size: 16),
                label: const Text('Request a return'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md, vertical: 6),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
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
        AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.md,
      ),
      child: Row(
        children: [
          Icon(
            invoice.isPaid
                ? Icons.verified_rounded
                : Icons.receipt_long_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Download invoice',
            onPressed: downloading ? null : onDownload,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: downloading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.download_rounded, color: color),
          ),
          if (canOpen)
            Icon(Icons.chevron_right_rounded, size: 18, color: color),
        ],
      ),
    );

    if (!canOpen) return content;

    return InkWell(
      onTap: () => _openInvoice(context),
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppSizes.radiusMd),
      ),
      child: content,
    );
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
      return (
        AppColors.success,
        'Paid · Invoice ${invoice.invoiceNo}',
      );
    }
    if (invoice.isPartiallyPaid) {
      return (
        AppColors.warning,
        '${AppStrings.currencySymbol}${invoice.paidAmount.toStringAsFixed(0)} of '
            '${AppStrings.currencySymbol}${invoice.total.toStringAsFixed(0)} paid · '
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
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
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: Container(
                width: 56, height: 56,
                color: AppColors.heroPanel,
                child: item.imageUrl == null
                    ? const Icon(Icons.image_outlined,
                        color: AppColors.muted, size: 20)
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: ShapeDecoration(
                          color: AppColors.heroPanel,
                          shape: AppShapes.squircle(AppSizes.radiusFull),
                        ),
                        child: Text(
                          'Qty ${_qty(item.quantity)}',
                          style: const TextStyle(
                            color: AppColors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        item.unit,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${AppStrings.currencySymbol}${item.unitPrice.toStringAsFixed(2)} each',
                        style: const TextStyle(
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row at the top of the summary — replaces the old
          // top-of-page hero banner. Icon + headline + small subtext on
          // a single line, matching the existing bill-row rhythm.
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: Row(
              children: [
                Icon(status.icon, color: status.color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    status.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: status.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (status.subtext != null)
                  Text(
                    status.subtext!,
                    style: TextStyle(
                      color: status.color.withValues(alpha: 0.8),
                      fontSize: 11,
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
          const SizedBox(height: 4),
          Text(
            usedInvoices
                ? 'Confirmed totals from the shops\' invoices.'
                : 'The shops will confirm the final amount when they accept your order.',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
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
    final Widget val;
    if (valueLabel != null) {
      val = Text(
        valueLabel!,
        style: TextStyle(
          color: col,
          fontSize: bold ? 16 : 13,
          fontWeight: FontWeight.w800,
        ),
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
              style: TextStyle(
                color: bold ? AppColors.black : AppColors.muted,
                fontSize: bold ? 14 : 13,
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

// ─── Note card ───────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  final String note;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Text(
        note,
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 13,
          height: 1.5,
        ),
      ),
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
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.muted),
            const SizedBox(height: AppSizes.md),
            const Text(
              AppStrings.somethingWentWrong,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.lg),
            AppButton.secondary(
              label: AppStrings.tryAgain,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
