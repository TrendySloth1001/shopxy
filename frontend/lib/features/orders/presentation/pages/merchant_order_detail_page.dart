import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy/features/orders/domain/entities/merchant_order.dart';
import 'package:shopxy/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/stock/presentation/widgets/stock_bottom_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class MerchantOrderDetailPage extends StatefulWidget {
  const MerchantOrderDetailPage({super.key, required this.orderId});
  final int orderId;

  @override
  State<MerchantOrderDetailPage> createState() =>
      _MerchantOrderDetailPageState();
}

class _MerchantOrderDetailPageState extends State<MerchantOrderDetailPage> {
  MerchantOrderDetail? _order;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  /// Set on a stock-shortfall failure so we can highlight the offending
  /// line in the items list.
  int? _shortfallProductId;

  /// Collapses the verbose customer card into a sticky summary header
  /// once the user scrolls past it. ScrollController offset > threshold.
  final _scrollCtrl = ScrollController();
  bool _stickyHeaderVisible = false;
  static const _stickyThreshold = 96.0;

  /// Stock-in drafts created in this session via the Restock flow.
  /// Surfaced as an inline confirm card so the merchant can post the
  /// stock without leaving the order — confirming a draft posts the
  /// ledger row, after which we drop it from this list and reload the
  /// order so the stock chips update.
  final List<_PendingStockDraft> _pendingStockDrafts = [];
  final Set<int> _confirmingDraftIds = {};

  static final _date = DateFormat('d MMM y · h:mm a');
  static final _relativeFmt = DateFormat('h:mm a');
  static final _currency = NumberFormat.currency(
    symbol: AppStrings.currencySymbol,
    decimalDigits: 2,
  );
  static final _currencyCompact = NumberFormat.compactCurrency(
    symbol: AppStrings.currencySymbol,
  );

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollCtrl.offset > _stickyThreshold;
    if (shouldShow != _stickyHeaderVisible) {
      setState(() => _stickyHeaderVisible = shouldShow);
    }
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

  /// Confirm bottom sheet spelling out the side-effect ("creates a draft
  /// invoice"). Used to be one-tap → real invoice; misclick territory.
  /// When the detail page already shows a stock shortfall, the sheet
  /// switches to a louder warning tone so the merchant doesn't fail the
  /// invoice later.
  Future<void> _confirm() async {
    final order = _order;
    if (order == null) return;

    final shortfall = order.hasStockShortfall;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) => _ConfirmOrderSheet(shortfall: shortfall),
    );
    if (ok != true || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final ordersProvider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _shortfallProductId = null;
    });
    try {
      final result = await ordersProvider.confirm(widget.orderId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ordersInvoiceCreated(result.invoiceNo))),
      );
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(invoiceId: result.invoiceId),
        ),
      );
    } on OrderConfirmException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _shortfallProductId = e.code == 'INSUFFICIENT_STOCK'
            ? e.productId
            : null;
      });
      // Server is the source of truth for stock; re-pull so the
      // shortfall chip on the page matches what just blocked the confirm.
      if (e.code == 'INSUFFICIENT_STOCK') {
        unawaitedReload();
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      setState(() => _busy = false);
    }
  }

  void unawaitedReload() {
    // Fire-and-forget; mounted check inside.
    _load();
  }

  /// Styled decline flow — bottom sheet with quick-pick reason chips
  /// and an optional free-form note. Chips prefill the note so the
  /// merchant rarely has to type one.
  Future<void> _reject() async {
    final result = await showModalBottomSheet<({bool ok, String note})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) => const _DeclineOrderSheet(),
    );
    if (result == null || !result.ok || !mounted) return;
    final note = result.note;

    final l10n = AppLocalizations.of(context);
    final ordersProvider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ordersProvider.reject(widget.orderId, note: note);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.ordersDeclinedToast)));
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
        setState(() => _busy = false);
      }
    }
  }

  /// Shipping milestone flow — bottom sheet with a milestone selector
  /// (PACKED → RETURNED), courier/AWB/ETA fields for the in-transit
  /// milestones, and an optional note. Mirrors merchant-web's
  /// ShippingModal; marking DELIVERED is what opens the customer's
  /// return window, so app-only merchants need this too.
  Future<void> _updateShipping() async {
    final result = await showModalBottomSheet<_ShippingUpdateResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) => const _ShippingUpdateSheet(),
    );
    if (result == null || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final ordersProvider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ordersProvider.addShippingEvent(
        widget.orderId,
        type: result.type,
        courier: result.courier,
        awb: result.awb,
        eta: result.eta,
        note: result.note,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ordersShippingPosted)),
      );
      setState(() => _busy = false);
      // Re-pull so the events timeline reflects the new milestone.
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      setState(() => _busy = false);
    }
  }

  /// Loads the full product for a line and opens the stock-in sheet so
  /// the merchant can resolve a shortfall without leaving the order.
  /// When the sheet returns a new draft invoice id we add it to the
  /// pending list so an inline confirm card appears at the top of the
  /// page — the merchant can post the stock right there.
  Future<void> _restock(MerchantOrderItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final ds = context.read<ProductsRemoteDataSource>();
    try {
      final product = await ds.getProduct(item.productId);
      if (!mounted) return;
      final draftId = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
        builder: (_) =>
            StockBottomSheet(product: product, initialType: 'STOCK_IN'),
      );
      if (!mounted) return;
      if (draftId != null) {
        setState(() {
          _pendingStockDrafts.add(
            _PendingStockDraft(
              invoiceId: draftId,
              productId: item.productId,
              productName: item.productName,
              unit: item.unit,
            ),
          );
        });
        // We don't reload the order yet — stock chips only move once
        // the draft is confirmed (the ledger posts on confirm, not on
        // draft create). The inline confirm card handles that.
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _confirmStockDraft(_PendingStockDraft draft) async {
    if (_confirmingDraftIds.contains(draft.invoiceId)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _confirmingDraftIds.add(draft.invoiceId));
    try {
      await context.read<InvoicesProvider>().updateStatus(
        draft.invoiceId,
        'CONFIRMED',
      );
      if (!mounted) return;
      setState(() {
        _pendingStockDrafts.removeWhere((d) => d.invoiceId == draft.invoiceId);
        _confirmingDraftIds.remove(draft.invoiceId);
      });
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ordersStockPosted(draft.productName))),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirmingDraftIds.remove(draft.invoiceId));
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _dismissStockDraft(_PendingStockDraft draft) {
    setState(() {
      _pendingStockDrafts.removeWhere((d) => d.invoiceId == draft.invoiceId);
    });
  }

  Future<void> _restockFirstShortfall() async {
    final order = _order;
    if (order == null) return;
    final first = order.items.firstWhere(
      (i) => !i.stockOk && i.productActive,
      orElse: () => order.items.first,
    );
    await _restock(first);
  }

  Future<void> _launch(Uri uri) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ordersCouldNotOpenApp)),
      );
    }
  }

  Future<void> _callCustomer() async {
    final phone = _order?.customerPhone;
    if (phone == null || phone.isEmpty) return;
    await _launch(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _whatsappCustomer() async {
    final phone = _order?.customerPhone;
    if (phone == null || phone.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final order = _order!;
    final msg = Uri.encodeComponent(
      l10n.ordersWhatsappGreeting(order.customerName, '${order.id}'),
    );
    await _launch(Uri.parse('https://wa.me/$digits?text=$msg'));
  }

  Future<void> _emailCustomer() async {
    final email = _order?.customerEmail;
    if (email == null || email.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    await _launch(
      Uri(
        scheme: 'mailto',
        path: email,
        query:
            'subject=${Uri.encodeComponent(l10n.ordersEmailSubject('${_order!.id}'))}',
      ),
    );
  }

  Future<void> _shareSummary() async {
    final order = _order;
    if (order == null) return;
    final l10n = AppLocalizations.of(context);
    final lines = <String>[
      l10n.ordersShareHeader('${order.id}', order.customerName),
      _date.format(order.createdAt.toLocal()),
      '',
      for (final i in order.items)
        '• ${i.productName} × ${_qtyLabel(i.quantity)} ${i.unit} — ${_currency.format(i.total)}',
      '',
      '${l10n.ordersTotalsTotal}: ${_currency.format(order.subtotal)}',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = _order;
    final canWriteOrders = context.select<AuthProvider, bool>(
      (a) => a.user?.canWriteOrders ?? false,
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.ordersDetailTitle('${widget.orderId}'),
        actions: [
          if (order != null)
            IconButton(
              tooltip: l10n.ordersActionShare,
              icon: const AppIcon(AppIcons.iosShareRounded),
              onPressed: _shareSummary,
            ),
        ],
        bottom: order != null && _stickyHeaderVisible
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: _StickyContextStrip(order: order),
              )
            : null,
      ),
      body: _loading
          ? const _OrderDetailSkeleton()
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: _Body(
                order: order!,
                dateFmt: _date,
                relativeFmt: _relativeFmt,
                currency: _currency,
                currencyCompact: _currencyCompact,
                scrollController: _scrollCtrl,
                shortfallProductId: _shortfallProductId,
                pendingStockDrafts: _pendingStockDrafts,
                confirmingDraftIds: _confirmingDraftIds,
                onRestock: _restock,
                onRestockBanner: _restockFirstShortfall,
                onConfirmDraft: _confirmStockDraft,
                onDismissDraft: _dismissStockDraft,
                onCall: _callCustomer,
                onWhatsapp: _whatsappCustomer,
                onEmail: _emailCustomer,
                canWriteOrders: canWriteOrders,
                shippingBusy: _busy,
                onUpdateShipping: _updateShipping,
              ),
            ),
      bottomNavigationBar: order == null || !order.isPending
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: MaybeLocked(
                        allowed: canWriteOrders,
                        what: l10n.ordersManageWhat,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _reject,
                          icon: AppIcon(
                            AppIcons.closeRounded,
                            color: AppColors.error,
                          ),
                          label: Text(
                            l10n.ordersDecline,
                            style: TextStyle(color: AppColors.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(AppSizes.huge),
                            side: BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      flex: 2,
                      child: MaybeLocked(
                        allowed: canWriteOrders,
                        what: l10n.ordersManageWhat,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _confirm,
                          icon: const AppIcon(AppIcons.checkRounded),
                          label: Text(l10n.ordersConfirmAndCreateInvoice),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            minimumSize: const Size.fromHeight(AppSizes.huge),
                          ),
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

/// One-line collapsed summary shown under the AppBar once the user
/// scrolls past the customer card. Keeps "who + total" anchored.
class _StickyContextStrip extends StatelessWidget {
  const _StickyContextStrip({required this.order});
  final MerchantOrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: AppSizes.xxxl,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              order.customerName,
              style: theme.textTheme.bodyMedium?.bold,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${AppStrings.currencySymbol}${order.subtotal.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.order,
    required this.dateFmt,
    required this.relativeFmt,
    required this.currency,
    required this.currencyCompact,
    required this.scrollController,
    required this.shortfallProductId,
    required this.pendingStockDrafts,
    required this.confirmingDraftIds,
    required this.onRestock,
    required this.onRestockBanner,
    required this.onConfirmDraft,
    required this.onDismissDraft,
    required this.onCall,
    required this.onWhatsapp,
    required this.onEmail,
    required this.canWriteOrders,
    required this.shippingBusy,
    required this.onUpdateShipping,
  });
  final MerchantOrderDetail order;
  final DateFormat dateFmt;
  final DateFormat relativeFmt;
  final NumberFormat currency;
  final NumberFormat currencyCompact;
  final ScrollController scrollController;
  final int? shortfallProductId;
  final List<_PendingStockDraft> pendingStockDrafts;
  final Set<int> confirmingDraftIds;
  final void Function(MerchantOrderItem) onRestock;
  final VoidCallback onRestockBanner;
  final void Function(_PendingStockDraft) onConfirmDraft;
  final void Function(_PendingStockDraft) onDismissDraft;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;
  final VoidCallback onEmail;
  final bool canWriteOrders;
  final bool shippingBusy;
  final VoidCallback onUpdateShipping;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: AppSizes.md + FloatingAppBar.contentTopInset(context),
        bottom: AppSizes.md,
      ),
      children: [
        // Decision summary strip
        _DecisionSummaryStrip(
          order: order,
          relativeFmt: relativeFmt,
          currencyCompact: currencyCompact,
        ),
        const SizedBox(height: AppSizes.md),

        // Stock shortfall banner — louder + actionable
        if (order.isPending && order.hasStockShortfall)
          _ShortfallBanner(
            shortCount: order.shortItemCount,
            totalCount: order.items.length,
            onRestock: onRestockBanner,
          ),

        // Inline stock-draft confirm card — appears after the merchant
        // posts a Restock from this page so they can confirm the draft
        // (= actually move the stock) right here.
        if (pendingStockDrafts.isNotEmpty)
          _StockDraftCard(
            drafts: pendingStockDrafts,
            confirming: confirmingDraftIds,
            onConfirm: onConfirmDraft,
            onDismiss: onDismissDraft,
          ),

        // Customer card — avatar + reachability + linked-party badge
        _CustomerCard(
          order: order,
          onCall: onCall,
          onWhatsapp: onWhatsapp,
          onEmail: onEmail,
        ),

        // Delivery address
        if (order.customerAddress != null &&
            order.customerAddress!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AppIcon(
                    AppIcons.locationOnOutlined,
                    size: AppSizes.iconSm,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: AppSizes.xs),
                Expanded(
                  child: Text(
                    order.customerAddress!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Customer note — promoted right under the customer card
        if (order.note != null && order.note!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _CustomerNote(note: order.note!),
        ],

        // Date row with status journey strip
        const SizedBox(height: AppSizes.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                dateFmt.format(order.createdAt.toLocal()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              AppStatusBadge(label: order.status, tone: _statusTone(order)),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: _StatusJourney(order: order),
        ),
        const SizedBox(height: AppSizes.lg),

        const AppDivider(),
        for (final item in order.items)
          _ItemRow(
            item: item,
            currency: currency,
            highlight: item.productId == shortfallProductId,
            onTap: order.isPending ? () => onRestock(item) : null,
          ),
        const AppDivider(),

        // Itemized totals block
        _TotalsBlock(order: order, currency: currency),

        // Open invoice CTA when this order has already been confirmed
        if (order.linkedInvoiceNo != null) ...[
          const SizedBox(height: AppSizes.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InvoiceDetailPage(invoiceId: order.invoiceId!),
                ),
              ),
              icon: const AppIcon(AppIcons.receiptLongOutlined),
              label: Text(l10n.ordersOpenInvoice(order.linkedInvoiceNo!)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.huge),
              ),
            ),
          ),
        ],

        // Shipping milestones — apply once an order is confirmed.
        // Mirrors merchant-web: section shows when the order is past
        // pending or already has events on record.
        if (order.isConfirmed || order.events.isNotEmpty) ...[
          const SizedBox(height: AppSizes.lg),
          const AppDivider(),
          const SizedBox(height: AppSizes.md),
          _ShippingSection(
            order: order,
            dateFmt: dateFmt,
            canWriteOrders: canWriteOrders,
            busy: shippingBusy,
            onUpdateShipping: onUpdateShipping,
          ),
        ],
        const SizedBox(height: AppSizes.huge),
      ],
    );
  }

  AppStatusTone _statusTone(MerchantOrder o) {
    if (o.isConfirmed) return AppStatusTone.success;
    if (o.isRejected) return AppStatusTone.error;
    if (o.isCancelled) return AppStatusTone.neutral;
    return AppStatusTone.warning;
  }
}

/// Pill-row above the customer block: time + items · qty · total.
class _DecisionSummaryStrip extends StatelessWidget {
  const _DecisionSummaryStrip({
    required this.order,
    required this.relativeFmt,
    required this.currencyCompact,
  });
  final MerchantOrderDetail order;
  final DateFormat relativeFmt;
  final NumberFormat currencyCompact;

  String _relative(AppLocalizations l10n, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.ordersJustNow;
    if (diff.inMinutes < 60) return l10n.ordersMinAgo('${diff.inMinutes}');
    if (diff.inHours < 24) {
      return l10n.ordersHrAgo('${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return l10n.ordersDayAgo('${diff.inDays}');
    }
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final urgency =
        DateTime.now().difference(order.createdAt).inHours >= 1 &&
        order.isPending;

    final totalQty = order.items.fold<double>(0, (acc, i) => acc + i.quantity);
    final qtyLabel = totalQty.truncateToDouble() == totalQty
        ? totalQty.toInt().toString()
        : totalQty.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (urgency)
                Container(
                  width: AppSizes.sm,
                  height: AppSizes.sm,
                  margin: const EdgeInsets.only(right: AppSizes.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                '${relativeFmt.format(order.createdAt.toLocal())} · ${_relative(l10n, order.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SummaryStat(
                  label: l10n.ordersSummaryItemsLabel,
                  value: '${order.items.length}',
                ),
                const _ThinVRule(),
                _SummaryStat(
                  label: l10n.ordersSummaryQtyLabel,
                  value: qtyLabel,
                ),
                const _ThinVRule(),
                _SummaryStat(
                  label: l10n.ordersSummaryTotalLabel,
                  value: currencyCompact.format(order.subtotal),
                  emphasis: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Editorial three-up: value on top, tiny label below, separated by a
/// hairline rule — matches the dashboard's `_QuickStats` so the order
/// detail reads as part of the same surface, not a stack of cards.
class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: emphasis ? AppColors.brandStrong : AppColors.black,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSizes.xxs),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinVRule extends StatelessWidget {
  const _ThinVRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      color: AppColors.hairline,
    );
  }
}

class _ShortfallBanner extends StatelessWidget {
  const _ShortfallBanner({
    required this.shortCount,
    required this.totalCount,
    required this.onRestock,
  });
  final int shortCount;
  final int totalCount;
  final VoidCallback onRestock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.warningSoft,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(color: AppColors.warning),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AppIcon(
                    AppIcons.warningAmberRounded,
                    color: AppColors.warning,
                    size: AppSizes.iconMd,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ordersShortfallTitle('$shortCount', '$totalCount'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSizes.xxs),
                      Text(
                        l10n.ordersShortfallBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onRestock,
                  icon: const AppIcon(
                    AppIcons.addBoxOutlined,
                    size: AppSizes.iconSm,
                  ),
                  label: Text(l10n.ordersRestock),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.order,
    required this.onCall,
    required this.onWhatsapp,
    required this.onEmail,
  });
  final MerchantOrderDetail order;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;
  final VoidCallback onEmail;

  String get _initial {
    final n = order.customerName.trim();
    if (n.isEmpty) return '?';
    return n.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final phone = order.customerPhone;
    final email = order.customerEmail;
    final canCall = phone != null && phone.isNotEmpty;
    final canEmail = email != null && email.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSizes.huge,
                height: AppSizes.huge,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                ),
                child: Text(
                  _initial,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: theme.textTheme.titleMedium?.extraBold,
                    ),
                    if (phone != null)
                      Text(
                        phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    if (email != null)
                      Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (order.isLinkedCustomer)
                AppStatusBadge(
                  label: l10n.ordersLinkedParty,
                  icon: AppIcons.verifiedOutlined,
                  tone: AppStatusTone.success,
                ),
            ],
          ),
          if (canCall || canEmail) ...[
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                if (canCall)
                  _ReachButton(
                    icon: AppIcons.callRounded,
                    label: l10n.ordersCall,
                    onTap: onCall,
                  ),
                if (canCall) const SizedBox(width: AppSizes.sm),
                if (canCall)
                  _ReachButton(
                    icon: AppIcons.chatRounded,
                    label: l10n.ordersWhatsapp,
                    onTap: onWhatsapp,
                  ),
                if (canEmail) const SizedBox(width: AppSizes.sm),
                if (canEmail)
                  _ReachButton(
                    icon: AppIcons.emailOutlined,
                    label: l10n.ordersEmail,
                    onTap: onEmail,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReachButton extends StatelessWidget {
  const _ReachButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final AppIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surfaceTint,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: AppSizes.iconSm, color: AppColors.black),
              const SizedBox(width: AppSizes.sm),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerNote extends StatelessWidget {
  const _CustomerNote({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.surfaceTint,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(
                  AppIcons.formatQuoteRounded,
                  size: AppSizes.iconSm,
                  color: AppColors.muted,
                ),
                const SizedBox(width: AppSizes.xs),
                Text(
                  l10n.ordersCustomerNote.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            SelectableText(
              note,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.black,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusJourney extends StatelessWidget {
  const _StatusJourney({required this.order});
  final MerchantOrderDetail order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invoiced = order.linkedInvoiceNo != null;
    final confirmed = order.isConfirmed;
    final placed = true;
    // Paid state comes from the linked invoice's payment summary (receipts,
    // which include the customer's online/wallet payments). Lit when fully
    // settled.
    final paid = order.isPaid;

    final steps = <_JourneyStep>[
      _JourneyStep(label: l10n.ordersJourneyPlaced, done: placed),
      _JourneyStep(
        label: order.isRejected
            ? l10n.ordersJourneyDeclined
            : order.isCancelled
            ? l10n.ordersJourneyCancelled
            : l10n.ordersJourneyConfirmed,
        done: confirmed,
        failed: order.isRejected || order.isCancelled,
      ),
      _JourneyStep(label: l10n.ordersJourneyInvoiced, done: invoiced),
      _JourneyStep(label: l10n.ordersJourneyPaid, done: paid),
    ];

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _JourneyDot(step: steps[i]),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 1,
                color: steps[i + 1].done ? AppColors.brand : AppColors.hairline,
              ),
            ),
        ],
      ],
    );
  }
}

class _JourneyStep {
  const _JourneyStep({
    required this.label,
    required this.done,
    this.failed = false,
  });
  final String label;
  final bool done;
  final bool failed;
}

class _JourneyDot extends StatelessWidget {
  const _JourneyDot({required this.step});
  final _JourneyStep step;

  @override
  Widget build(BuildContext context) {
    final color = step.failed
        ? AppColors.error
        : step.done
        ? AppColors.brand
        : AppColors.hairline;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSizes.md,
          height: AppSizes.md,
          decoration: BoxDecoration(
            color: step.done || step.failed ? color : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.4),
          ),
          child: step.done && !step.failed
              ? AppIcon(AppIcons.check, size: 8, color: AppColors.white)
              : null,
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          step.label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: step.done || step.failed ? color : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.currency,
    required this.highlight,
    required this.onTap,
  });
  final MerchantOrderItem item;
  final NumberFormat currency;

  /// True if this row was flagged by the most recent stock-shortfall
  /// confirm failure — gives the merchant a visual to scroll to.
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtyLabel = _qtyLabel(item.quantity);

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductThumb(url: item.productImageUrl),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: theme.textTheme.bodyMedium?.bold),
                Text(
                  '${item.productSku} · '
                  '${currency.format(item.unitPrice)} / ${item.unit}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                _StockChip(item: item),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$qtyLabel ${item.unit}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSizes.xxs),
              SizedBox(
                width: 80,
                child: Text(
                  currency.format(item.total),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.extraBold,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final wrapped = onTap == null
        ? content
        : InkWell(onTap: onTap, child: content);
    if (!highlight) return wrapped;
    return Container(
      color: AppColors.warningSoft.withValues(alpha: 0.6),
      child: wrapped,
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final shape = AppShapes.squircle(AppSizes.radiusSm);
    final placeholder = Container(
      width: AppSizes.productThumbSize,
      height: AppSizes.productThumbSize,
      decoration: ShapeDecoration(color: AppColors.heroPanel, shape: shape),
      alignment: Alignment.center,
      child: AppIcon(
        AppIcons.inventory2Outlined,
        size: AppSizes.iconMd,
        color: AppColors.muted,
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: AppSizes.productThumbSize,
        height: AppSizes.productThumbSize,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({required this.item});
  final MerchantOrderItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stock = item.stockQuantity;
    if (!item.productActive) {
      return _Chip(
        label: l10n.ordersInactiveProduct,
        color: AppColors.error,
        soft: AppColors.errorSoft,
        icon: AppIcons.blockRounded,
      );
    }
    if (stock == null) {
      return _Chip(
        label: l10n.ordersStockUnknown,
        color: AppColors.muted,
        soft: AppColors.surfaceTint,
        icon: AppIcons.helpOutlineRounded,
      );
    }
    final ask = _qtyLabel(item.quantity);
    final have = _qtyLabel(stock);
    if (item.stockOk) {
      return _Chip(
        label: l10n.ordersStockOk(ask, have, item.unit),
        color: AppColors.success,
        soft: AppColors.successSoft,
        icon: AppIcons.checkCircleOutlineRounded,
      );
    }
    final short = _qtyLabel(item.shortfall);
    return _Chip(
      label: l10n.ordersStockShort(ask, have, short),
      color: AppColors.warning,
      soft: AppColors.warningSoft,
      icon: AppIcons.warningAmberRounded,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.soft,
    required this.icon,
  });
  final String label;
  final Color color;
  final Color soft;
  final AppIconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2),
      decoration: ShapeDecoration(
        color: soft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSizes.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsBlock extends StatelessWidget {
  const _TotalsBlock({required this.order, required this.currency});
  final MerchantOrderDetail order;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final subtotal = order.subtotal;
    // We don't have tax/discount fields snapshotted on the request yet;
    // surface them as zero rows so the merchant sees the shape they'll
    // get on the invoice and can spot mismatches early.
    const tax = 0.0;
    const discount = 0.0;
    final total = subtotal + tax - discount;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalLine(
            label: l10n.ordersTotalsSubtotal,
            value: currency.format(subtotal),
          ),
          _TotalLine(
            label: l10n.ordersTotalsTax,
            value: currency.format(tax),
            muted: true,
          ),
          _TotalLine(
            label: l10n.ordersTotalsDiscount,
            value: '−${currency.format(discount)}',
            muted: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
            child: Divider(height: 1, color: AppColors.hairline),
          ),
          _TotalLine(
            label: l10n.ordersTotalsTotal,
            value: currency.format(total),
            emphasis: true,
          ),
          if (order.isPending && order.hasStockShortfall) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              l10n.ordersPartialFulfillFootnote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.muted = false,
    this.emphasis = false,
  });
  final String label;
  final String value;
  final bool muted;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasis
        ? theme.textTheme.titleMedium?.extraBold
        : theme.textTheme.bodyMedium?.copyWith(
            color: muted ? AppColors.muted : AppColors.black,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? AppColors.inverseSurface : AppColors.surfaceTint,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? AppColors.onInverse : AppColors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      top: true,
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.cloudOffRounded,
                size: AppSizes.iconHuge,
                color: AppColors.muted,
              ),
              const SizedBox(height: AppSizes.md),
              Text(l10n.ordersError, style: theme.textTheme.titleMedium?.bold),
              const SizedBox(height: AppSizes.xs),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const AppIcon(AppIcons.refreshRounded),
                label: Text(l10n.ordersRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _qtyLabel(double q) =>
    q.truncateToDouble() == q ? q.toInt().toString() : q.toStringAsFixed(2);

/// Localized label for a shipping milestone type. Falls back to the raw
/// type for any unmapped value (keeps historical/unknown milestones legible).
String _milestoneLabel(AppLocalizations l10n, String type) {
  switch (type) {
    case 'PACKED':
      return l10n.ordersMilestonePacked;
    case 'SHIPPED':
      return l10n.ordersMilestoneShipped;
    case 'OUT_FOR_DELIVERY':
      return l10n.ordersMilestoneOutForDelivery;
    case 'DELIVERED':
      return l10n.ordersMilestoneDelivered;
    case 'RETURNED':
      return l10n.ordersMilestoneReturned;
    default:
      return type;
  }
}

/// Modal bottom sheet replacement for the old confirm dialog. Same
/// copy + same destructive-tone fallback when a shortfall is detected;
/// just a sheet so it composes with the rest of the page's modal style.
class _ConfirmOrderSheet extends StatelessWidget {
  const _ConfirmOrderSheet({required this.shortfall});
  final bool shortfall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSizes.lg,
          right: AppSizes.lg,
          top: AppSizes.sm,
          bottom: AppSizes.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Text(
              shortfall
                  ? l10n.ordersConfirmShortfallTitle
                  : l10n.ordersConfirmOrderTitle,
              style: theme.textTheme.titleMedium?.extraBold,
            ),
            const SizedBox(height: AppSizes.sm),
            if (shortfall)
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                margin: const EdgeInsets.only(bottom: AppSizes.sm),
                decoration: ShapeDecoration(
                  color: AppColors.warningSoft,
                  shape: AppShapes.squircle(
                    AppSizes.radiusMd,
                    side: BorderSide(color: AppColors.warning),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: AppIcon(
                        AppIcons.warningAmberRounded,
                        color: AppColors.warning,
                        size: AppSizes.iconMd,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        l10n.ordersConfirmShortfallWarning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              l10n.ordersConfirmOrderBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.huge),
                      side: BorderSide(color: AppColors.hairline),
                    ),
                    child: Text(l10n.ordersNotYet),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: shortfall
                          ? AppColors.warning
                          : AppColors.brand,
                      minimumSize: const Size.fromHeight(AppSizes.huge),
                    ),
                    child: Text(l10n.ordersConfirmOrder),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeclineOrderSheet extends StatefulWidget {
  const _DeclineOrderSheet();

  @override
  State<_DeclineOrderSheet> createState() => _DeclineOrderSheetState();
}

class _DeclineOrderSheetState extends State<_DeclineOrderSheet> {
  final _ctrl = TextEditingController();
  // Stable identity for the selected quick-pick reason. 'OTHER' clears the
  // note field; the others prefill it with their localized label.
  String? _selectedReasonKey;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pickReason(String key, String label) {
    setState(() {
      _selectedReasonKey = key;
      if (key == 'OTHER') {
        _ctrl.clear();
      } else {
        _ctrl.text = label;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Quick-pick decline reasons: stable key + localized label.
    final reasons = <(String, String)>[
      ('OUT_OF_STOCK', l10n.ordersDeclineReasonOutOfStock),
      ('CLOSED', l10n.ordersDeclineReasonClosed),
      ('PRICE_CHANGED', l10n.ordersDeclineReasonPriceChanged),
      ('OTHER', l10n.ordersDeclineReasonOther),
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSizes.lg,
          right: AppSizes.lg,
          top: AppSizes.sm,
          bottom: AppSizes.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Text(
              l10n.ordersDeclineOrderTitle,
              style: theme.textTheme.titleMedium?.extraBold,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              l10n.ordersDeclineOrderBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final (key, label) in reasons)
                  _ReasonChip(
                    label: label,
                    selected: _selectedReasonKey == key,
                    onTap: () => _pickReason(key, label),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.ordersDeclineOrderNoteHint,
                border: OutlineInputBorder(
                  borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, (ok: false, note: '')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.huge),
                      side: BorderSide(color: AppColors.hairline),
                    ),
                    child: Text(l10n.ordersKeep),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, (ok: true, note: _ctrl.text)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      minimumSize: const Size.fromHeight(AppSizes.huge),
                    ),
                    child: Text(l10n.ordersDeclineOrder),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shipping updates ────────────────────────────────────────────────────────

/// What the shipping sheet hands back to the page. Courier / AWB / ETA
/// are only populated for the in-transit milestones, matching
/// merchant-web's ShippingModal.
typedef _ShippingUpdateResult = ({
  String type,
  String? courier,
  String? awb,
  DateTime? eta,
  String? note,
});

/// Chronological list of recorded milestones + the "Update shipping"
/// entry point (confirmed orders only — the backend rejects events on
/// anything else).
class _ShippingSection extends StatelessWidget {
  const _ShippingSection({
    required this.order,
    required this.dateFmt,
    required this.canWriteOrders,
    required this.busy,
    required this.onUpdateShipping,
  });
  final MerchantOrderDetail order;
  final DateFormat dateFmt;
  final bool canWriteOrders;
  final bool busy;
  final VoidCallback onUpdateShipping;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.ordersShippingUpdates.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (order.isConfirmed)
                MaybeLocked(
                  allowed: canWriteOrders,
                  what: l10n.ordersManageWhat,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onUpdateShipping,
                    icon: const AppIcon(
                      AppIcons.localShippingOutlined,
                      size: AppSizes.iconSm,
                    ),
                    label: Text(l10n.ordersUpdateShipping),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: AppColors.hairline),
                      foregroundColor: AppColors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          if (order.events.isEmpty)
            Text(
              l10n.ordersNoShippingUpdates,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            )
          else
            for (final ev in order.events)
              _ShippingEventRow(event: ev, dateFmt: dateFmt),
        ],
      ),
    );
  }
}

class _ShippingEventRow extends StatelessWidget {
  const _ShippingEventRow({required this.event, required this.dateFmt});
  final MerchantOrderEvent event;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final meta = [
      dateFmt.format(event.occurredAt.toLocal()),
      if (event.courier != null && event.courier!.isNotEmpty) event.courier!,
      if (event.awb != null && event.awb!.isNotEmpty) event.awb!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: AppSizes.sm,
              height: AppSizes.sm,
              decoration: BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _milestoneLabel(l10n, event.type),
                  style: theme.textTheme.bodyMedium?.bold,
                ),
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                if (event.note != null && event.note!.isNotEmpty)
                  Text(
                    event.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for posting a shipping milestone. Courier / AWB / ETA
/// only show for SHIPPED and OUT_FOR_DELIVERY — same gating as
/// merchant-web's ShippingModal.
class _ShippingUpdateSheet extends StatefulWidget {
  const _ShippingUpdateSheet();

  @override
  State<_ShippingUpdateSheet> createState() => _ShippingUpdateSheetState();
}

class _ShippingUpdateSheetState extends State<_ShippingUpdateSheet> {
  // PR-H3 — RETURNED is deliberately not a postable milestone. The raw
  // shipping-event endpoint has no side effects (no refund / stock
  // add-back / credit-note GST reversal / transfer clawback), so returns
  // run through the dedicated returns flow. The backend rejects RETURNED
  // here, and historical RETURNED events still render in the timeline.
  // Labels are resolved from l10n at build time via _milestoneLabel.
  static const _milestoneTypes = <String>[
    'PACKED',
    'SHIPPED',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
  ];
  static final _etaFmt = DateFormat('d MMM · h:mm a');

  String _type = 'PACKED';
  final _courierCtrl = TextEditingController();
  final _awbCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _eta;

  /// Courier / AWB / ETA matter for in-transit milestones only.
  bool get _showLogistics => _type == 'SHIPPED' || _type == 'OUT_FOR_DELIVERY';

  @override
  void dispose() {
    _courierCtrl.dispose();
    _awbCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickEta() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _eta ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eta ?? now),
    );
    if (!mounted) return;
    setState(() {
      _eta = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 18,
        time?.minute ?? 0,
      );
    });
  }

  void _submit() {
    String? clean(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    Navigator.pop(context, (
      type: _type,
      courier: _showLogistics ? clean(_courierCtrl) : null,
      awb: _showLogistics ? clean(_awbCtrl) : null,
      eta: _showLogistics ? _eta : null,
      note: clean(_noteCtrl),
    ));
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSizes.lg,
          right: AppSizes.lg,
          top: AppSizes.sm,
          bottom: AppSizes.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Text(
                l10n.ordersUpdateShipping,
                style: theme.textTheme.titleMedium?.extraBold,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                l10n.ordersShippingSheetBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Wrap(
                spacing: AppSizes.sm,
                runSpacing: AppSizes.sm,
                children: [
                  for (final value in _milestoneTypes)
                    _ReasonChip(
                      label: _milestoneLabel(l10n, value),
                      selected: _type == value,
                      onTap: () => setState(() => _type = value),
                    ),
                ],
              ),
              if (_showLogistics) ...[
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: _courierCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration(l10n.ordersCourierHint),
                ),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: _awbCtrl,
                  decoration: _fieldDecoration(l10n.ordersAwbHint),
                ),
                const SizedBox(height: AppSizes.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickEta,
                        icon: const AppIcon(
                          AppIcons.scheduleRounded,
                          size: AppSizes.iconSm,
                        ),
                        label: Text(
                          _eta == null
                              ? l10n.ordersEtaHint
                              : _etaFmt.format(_eta!),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(AppSizes.huge),
                          side: BorderSide(color: AppColors.hairline),
                          foregroundColor: AppColors.black,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                    if (_eta != null)
                      IconButton(
                        tooltip: l10n.ordersClearEta,
                        onPressed: () => setState(() => _eta = null),
                        icon: const AppIcon(
                          AppIcons.closeRounded,
                          size: AppSizes.iconSm,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: _fieldDecoration(l10n.ordersNoteHint),
              ),
              const SizedBox(height: AppSizes.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppSizes.huge),
                        side: BorderSide(color: AppColors.hairline),
                      ),
                      child: Text(l10n.ordersCancel),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const AppIcon(
                        AppIcons.localShippingOutlined,
                        size: AppSizes.iconSm,
                      ),
                      label: Text(l10n.ordersSaveUpdate),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        minimumSize: const Size.fromHeight(AppSizes.huge),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppSizes.xxxl,
        height: AppSizes.xs,
        margin: const EdgeInsets.only(bottom: AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.hairline,
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusFull),
        ),
      ),
    );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────────────────

/// Full-page skeleton shown while the order detail is loading.
/// Mirrors the scrollable layout: decision summary strip → optional
/// shortfall banner placeholder → customer avatar + info lines →
/// address line → date + status journey → item rows (×4) → dividers →
/// totals section → optional invoice button placeholder.
class _OrderDetailSkeleton extends StatelessWidget {
  const _OrderDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: AppSizes.md + FloatingAppBar.contentTopInset(context),
        bottom: AppSizes.md,
      ),
      children: const [
        _SummaryStripSkeleton(),
        SizedBox(height: AppSizes.md),
        _ShortfallBannerSkeleton(),
        SizedBox(height: AppSizes.md),
        _CustomerCardSkeleton(),
        SizedBox(height: AppSizes.sm),
        _AddressLineSkeleton(),
        SizedBox(height: AppSizes.md),
        _DateStatusSkeleton(),
        SizedBox(height: AppSizes.sm),
        _StatusJourneySkeleton(),
        SizedBox(height: AppSizes.lg),
        _ItemsDivider(),
        _ItemRowSkeleton(),
        _ItemRowSkeleton(),
        _ItemRowSkeleton(),
        _ItemRowSkeleton(),
        _ItemsDivider(),
        _TotalsBlockSkeleton(),
        SizedBox(height: AppSizes.lg),
        _InvoiceButtonSkeleton(),
        SizedBox(height: AppSizes.huge),
      ],
    );
  }
}

/// Three stat boxes separated by hairline dividers (Items / Qty / Total).
class _SummaryStripSkeleton extends StatelessWidget {
  const _SummaryStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // relative-time line
          const AppShimmerLine(widthFactor: 0.45, height: AppSizes.md),
          const SizedBox(height: AppSizes.sm),
          IntrinsicHeight(
            child: Row(
              children: [
                _StatBoxSkeleton(),
                const _ThinVRule(),
                _StatBoxSkeleton(),
                const _ThinVRule(),
                _StatBoxSkeleton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBoxSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AppShimmerLine(widthFactor: 0.55, height: AppSizes.xxl),
          SizedBox(height: AppSizes.xs),
          AppShimmerLine(widthFactor: 0.7, height: AppSizes.sm),
        ],
      ),
    );
  }
}

/// Placeholder for the optional shortfall warning banner.
class _ShortfallBannerSkeleton extends StatelessWidget {
  const _ShortfallBannerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: AppShimmerBox(
        width: double.infinity,
        height: AppSizes.massive,
        radius: AppSizes.radiusMd,
      ),
    );
  }
}

/// Squircle avatar + name / phone / email lines.
class _CustomerCardSkeleton extends StatelessWidget {
  const _CustomerCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox(
            width: AppSizes.huge,
            height: AppSizes.huge,
            radius: AppSizes.radiusMd,
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.6, height: AppSizes.lg),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.5, height: AppSizes.md),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.7, height: AppSizes.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single address text line (icon placeholder + text).
class _AddressLineSkeleton extends StatelessWidget {
  const _AddressLineSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        children: const [
          AppShimmerBox(
            width: AppSizes.iconSm,
            height: AppSizes.iconSm,
            radius: AppSizes.radiusFull,
          ),
          SizedBox(width: AppSizes.xs),
          Expanded(
            child: AppShimmerLine(widthFactor: 0.8, height: AppSizes.md),
          ),
        ],
      ),
    );
  }
}

/// Date text on the left, status badge placeholder on the right.
class _DateStatusSkeleton extends StatelessWidget {
  const _DateStatusSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        children: const [
          Expanded(
            child: AppShimmerLine(widthFactor: 0.5, height: AppSizes.md),
          ),
          SizedBox(width: AppSizes.md),
          AppShimmerBox(
            width: 72,
            height: AppSizes.xl,
            radius: AppSizes.radiusFull,
          ),
        ],
      ),
    );
  }
}

/// Four dots connected by lines — mirrors _StatusJourney.
class _StatusJourneySkeleton extends StatelessWidget {
  const _StatusJourneySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            _JourneyDotSkeleton(),
            if (i < 3)
              const Expanded(child: AppShimmerBox(height: 1, radius: 0)),
          ],
        ],
      ),
    );
  }
}

class _JourneyDotSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        AppShimmerBox(
          width: AppSizes.md,
          height: AppSizes.md,
          radius: AppSizes.radiusFull,
        ),
        SizedBox(height: AppSizes.xs),
        AppShimmerBox(
          width: 40,
          height: AppSizes.sm,
          radius: AppSizes.radiusFull,
        ),
      ],
    );
  }
}

/// Thin horizontal rule matching AppDivider visual weight.
class _ItemsDivider extends StatelessWidget {
  const _ItemsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: AppColors.hairline);
  }
}

/// Single item row skeleton: thumbnail box + name/sku/chip lines + qty/total.
class _ItemRowSkeleton extends StatelessWidget {
  const _ItemRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox(
            width: AppSizes.productThumbSize,
            height: AppSizes.productThumbSize,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.65, height: AppSizes.md),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.5, height: AppSizes.md),
                SizedBox(height: AppSizes.xs),
                // Stock chip placeholder
                AppShimmerBox(
                  width: 100,
                  height: AppSizes.lg,
                  radius: AppSizes.radiusFull,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppShimmerBox(
                width: 48,
                height: AppSizes.md,
                radius: AppSizes.radiusSm,
              ),
              SizedBox(height: AppSizes.xs),
              AppShimmerBox(
                width: 64,
                height: AppSizes.md,
                radius: AppSizes.radiusSm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Four label/value pairs with a divider before the total row.
class _TotalsBlockSkeleton extends StatelessWidget {
  const _TotalsBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Column(
        children: [
          const _TotalLineSkeleton(labelFactor: 0.3, valueFactor: 0.25),
          const SizedBox(height: AppSizes.xs),
          const _TotalLineSkeleton(labelFactor: 0.2, valueFactor: 0.2),
          const SizedBox(height: AppSizes.xs),
          const _TotalLineSkeleton(labelFactor: 0.25, valueFactor: 0.2),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
            child: Divider(height: 1, color: AppColors.hairline),
          ),
          const _TotalLineSkeleton(labelFactor: 0.2, valueFactor: 0.3),
        ],
      ),
    );
  }
}

class _TotalLineSkeleton extends StatelessWidget {
  const _TotalLineSkeleton({
    required this.labelFactor,
    required this.valueFactor,
  });
  final double labelFactor;
  final double valueFactor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppShimmerLine(widthFactor: labelFactor, height: AppSizes.md),
        ),
        AppShimmerBox(
          width: 72 * valueFactor / 0.25,
          height: AppSizes.md,
          radius: AppSizes.radiusSm,
        ),
      ],
    );
  }
}

/// Placeholder for the "Open invoice" button shown once an order has
/// been confirmed.
class _InvoiceButtonSkeleton extends StatelessWidget {
  const _InvoiceButtonSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: AppShimmerBox(
        width: double.infinity,
        height: AppSizes.huge,
        radius: AppSizes.radiusButton,
      ),
    );
  }
}

// ─── End skeleton ─────────────────────────────────────────────────────────────

/// Local model for a stock-in draft created during the current detail
/// session. We only need enough to render the inline confirm card and
/// post the status flip — full invoice data isn't fetched until the
/// merchant taps "Open".
class _PendingStockDraft {
  const _PendingStockDraft({
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.unit,
  });
  final int invoiceId;
  final int productId;
  final String productName;
  final String unit;
}

class _StockDraftCard extends StatelessWidget {
  const _StockDraftCard({
    required this.drafts,
    required this.confirming,
    required this.onConfirm,
    required this.onDismiss,
  });
  final List<_PendingStockDraft> drafts;
  final Set<int> confirming;
  final void Function(_PendingStockDraft) onConfirm;
  final void Function(_PendingStockDraft) onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.tileBg(AppColors.brandSoft),
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(color: AppColors.brand),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(
                  AppIcons.inventoryOutlined,
                  size: AppSizes.iconSm,
                  color: AppColors.brandStrong,
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  drafts.length == 1
                      ? l10n.ordersStockDraftPendingOne
                      : l10n.ordersStockDraftPendingMany('${drafts.length}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xxs),
            Text(
              l10n.ordersStockDraftHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.brandStrong,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            for (final d in drafts) ...[
              _StockDraftRow(
                draft: d,
                isConfirming: confirming.contains(d.invoiceId),
                onConfirm: () => onConfirm(d),
                onDismiss: () => onDismiss(d),
              ),
              if (d != drafts.last)
                Divider(height: 1, color: AppColors.hairline),
            ],
          ],
        ),
      ),
    );
  }
}

class _StockDraftRow extends StatelessWidget {
  const _StockDraftRow({
    required this.draft,
    required this.isConfirming,
    required this.onConfirm,
    required this.onDismiss,
  });
  final _PendingStockDraft draft;
  final bool isConfirming;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.productName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.ordersDraftInvoiceNo('${draft.invoiceId}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.ordersOpenDraft,
            onPressed: isConfirming
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          InvoiceDetailPage(invoiceId: draft.invoiceId),
                    ),
                  ),
            icon: const AppIcon(
              AppIcons.openInNewRounded,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.xs),
          FilledButton.icon(
            onPressed: isConfirming ? null : onConfirm,
            icon: isConfirming
                ? SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onInverse,
                    ),
                  )
                : const AppIcon(AppIcons.checkRounded, size: AppSizes.iconSm),
            label: Text(l10n.ordersConfirm),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            ),
          ),
          IconButton(
            tooltip: l10n.ordersHide,
            onPressed: isConfirming ? null : onDismiss,
            icon: const AppIcon(AppIcons.closeRounded, size: AppSizes.iconSm),
          ),
        ],
      ),
    );
  }
}
