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
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:url_launcher/url_launcher.dart';

class MerchantOrderDetailPage extends StatefulWidget {
  const MerchantOrderDetailPage({super.key, required this.orderId});
  final int orderId;

  @override
  State<MerchantOrderDetailPage> createState() => _MerchantOrderDetailPageState();
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
  static final _currency =
      NumberFormat.currency(symbol: AppStrings.currencySymbol, decimalDigits: 2);
  static final _currencyCompact =
      NumberFormat.compactCurrency(symbol: AppStrings.currencySymbol);

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
          _error = e.toString().replaceFirst('Exception: ', '');
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
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) => _ConfirmOrderSheet(shortfall: shortfall),
    );
    if (ok != true || !mounted) return;

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
        SnackBar(content: Text('Invoice ${result.invoiceNo} created')),
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
        _shortfallProductId = e.code == 'INSUFFICIENT_STOCK' ? e.productId : null;
      });
      // Server is the source of truth for stock; re-pull so the
      // shortfall chip on the page matches what just blocked the confirm.
      if (e.code == 'INSUFFICIENT_STOCK') {
        unawaitedReload();
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) => const _DeclineOrderSheet(),
    );
    if (result == null || !result.ok || !mounted) return;
    final note = result.note;

    final ordersProvider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ordersProvider.reject(widget.orderId, note: note);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Order declined')));
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _busy = false);
      }
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
        backgroundColor: AppColors.white,
        shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
        builder: (_) =>
            StockBottomSheet(product: product, initialType: 'STOCK_IN'),
      );
      if (!mounted) return;
      if (draftId != null) {
        setState(() {
          _pendingStockDrafts.add(_PendingStockDraft(
            invoiceId: draftId,
            productId: item.productId,
            productName: item.productName,
            unit: item.unit,
          ));
        });
        // We don't reload the order yet — stock chips only move once
        // the draft is confirmed (the ledger posts on confirm, not on
        // draft create). The inline confirm card handles that.
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _confirmStockDraft(_PendingStockDraft draft) async {
    if (_confirmingDraftIds.contains(draft.invoiceId)) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _confirmingDraftIds.add(draft.invoiceId));
    try {
      await context
          .read<InvoicesProvider>()
          .updateStatus(draft.invoiceId, 'CONFIRMED');
      if (!mounted) return;
      setState(() {
        _pendingStockDrafts.removeWhere(
          (d) => d.invoiceId == draft.invoiceId,
        );
        _confirmingDraftIds.remove(draft.invoiceId);
      });
      messenger.showSnackBar(
        SnackBar(content: Text('${draft.productName} stock posted')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirmingDraftIds.remove(draft.invoiceId));
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open that app')),
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
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final order = _order!;
    final msg = Uri.encodeComponent(
      'Hi ${order.customerName}, regarding your order #${order.id}.',
    );
    await _launch(Uri.parse('https://wa.me/$digits?text=$msg'));
  }

  Future<void> _emailCustomer() async {
    final email = _order?.customerEmail;
    if (email == null || email.isEmpty) return;
    await _launch(
      Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=${Uri.encodeComponent('Order #${_order!.id}')}',
      ),
    );
  }

  Future<void> _shareSummary() async {
    final order = _order;
    if (order == null) return;
    final lines = <String>[
      'Order #${order.id} from ${order.customerName}',
      _date.format(order.createdAt),
      '',
      for (final i in order.items)
        '• ${i.productName} × ${_qtyLabel(i.quantity)} ${i.unit} — ${_currency.format(i.total)}',
      '',
      'Total: ${_currency.format(order.subtotal)}',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final canWriteOrders = context.select<AuthProvider, bool>(
        (a) => a.user?.canWriteOrders ?? false);
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        actions: [
          if (order != null)
            IconButton(
              tooltip: AppStrings.orderActionShare,
              icon: const Icon(Icons.ios_share_rounded),
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
          ? const Center(child: CircularProgressIndicator())
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
                  ),
                ),
      bottomNavigationBar: order == null || !order.isPending
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: MaybeLocked(
                        allowed: canWriteOrders,
                        what: 'manage orders',
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _reject,
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.error),
                          label: const Text(
                            'Decline',
                            style: TextStyle(color: AppColors.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(AppSizes.huge),
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      flex: 2,
                      child: MaybeLocked(
                        allowed: canWriteOrders,
                        what: 'manage orders',
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _confirm,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text(AppStrings.confirmAndCreateInvoice),
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
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              order.customerName,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
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
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.location_on_outlined,
                    size: AppSizes.iconSm,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: AppSizes.xs),
                Expanded(
                  child: Text(
                    order.customerAddress!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
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
                dateFmt.format(order.createdAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              AppStatusBadge(
                label: order.status,
                tone: _statusTone(order),
              ),
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
        _TotalsBlock(
          order: order,
          currency: currency,
        ),

        // Open invoice CTA when this order has already been confirmed
        if (order.linkedInvoiceNo != null) ...[
          const SizedBox(height: AppSizes.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailPage(invoiceId: order.invoiceId!),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text('Open invoice ${order.linkedInvoiceNo!}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.huge),
              ),
            ),
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

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} hr${diff.inHours == 1 ? "" : "s"} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? "" : "s"} ago';
    }
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = DateTime.now().difference(order.createdAt).inHours >= 1 &&
        order.isPending;

    final totalQty = order.items.fold<double>(
      0,
      (acc, i) => acc + i.quantity,
    );
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
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                '${relativeFmt.format(order.createdAt)} · ${_relative(order.createdAt)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SummaryStat(
                  label: AppStrings.orderSummaryItemsLabel,
                  value: '${order.items.length}',
                ),
                const _ThinVRule(),
                _SummaryStat(
                  label: AppStrings.orderSummaryQtyLabel,
                  value: qtyLabel,
                ),
                const _ThinVRule(),
                _SummaryStat(
                  label: AppStrings.orderSummaryTotalLabel,
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
          const SizedBox(height: 2),
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
            side: const BorderSide(color: AppColors.warning),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: AppSizes.iconMd),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$shortCount of $totalCount '
                        '${totalCount == 1 ? "item" : "items"} short on stock',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Restock now or decline — the invoice will fail to '
                        'post otherwise.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.warning),
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
                  icon: const Icon(Icons.add_box_outlined, size: AppSizes.iconSm),
                  label: const Text(AppStrings.orderRestock),
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
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (phone != null)
                      Text(phone,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted)),
                    if (email != null)
                      Text(email,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              if (order.isLinkedCustomer)
                const AppStatusBadge(
                  label: AppStrings.orderLinkedParty,
                  icon: Icons.verified_outlined,
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
                    icon: Icons.call_rounded,
                    label: 'Call',
                    onTap: onCall,
                  ),
                if (canCall) const SizedBox(width: AppSizes.sm),
                if (canCall)
                  _ReachButton(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    onTap: onWhatsapp,
                  ),
                if (canEmail) const SizedBox(width: AppSizes.sm),
                if (canEmail)
                  _ReachButton(
                    icon: Icons.email_outlined,
                    label: 'Email',
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
  final IconData icon;
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
              Icon(icon, size: AppSizes.iconSm, color: AppColors.black),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.surfaceTint,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.format_quote_rounded,
                    size: AppSizes.iconSm, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  AppStrings.orderCustomerNote.toUpperCase(),
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
    final invoiced = order.linkedInvoiceNo != null;
    final confirmed = order.isConfirmed;
    final placed = true;
    // Paid state comes from the linked invoice's payment summary (receipts,
    // which include the customer's online/wallet payments). Lit when fully
    // settled.
    final paid = order.isPaid;

    final steps = <_JourneyStep>[
      _JourneyStep(label: AppStrings.orderJourneyPlaced, done: placed),
      _JourneyStep(
        label: order.isRejected
            ? 'Declined'
            : order.isCancelled
                ? 'Cancelled'
                : AppStrings.orderJourneyConfirmed,
        done: confirmed,
        failed: order.isRejected || order.isCancelled,
      ),
      _JourneyStep(label: AppStrings.orderJourneyInvoiced, done: invoiced),
      _JourneyStep(label: AppStrings.orderJourneyPaid, done: paid),
    ];

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _JourneyDot(step: steps[i]),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 1,
                color: steps[i + 1].done
                    ? AppColors.brand
                    : AppColors.hairline,
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
            color: step.done || step.failed ? color : AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.4),
          ),
          child: step.done && !step.failed
              ? const Icon(Icons.check, size: 8, color: AppColors.white)
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
                Text(
                  item.productName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${item.productSku} · '
                  '${currency.format(item.unitPrice)} / ${item.unit}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
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
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 80,
                child: Text(
                  currency.format(item.total),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
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
      child: const Icon(
        Icons.inventory_2_outlined,
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
    final stock = item.stockQuantity;
    if (!item.productActive) {
      return _Chip(
        label: AppStrings.inactiveProduct,
        color: AppColors.error,
        soft: AppColors.errorSoft,
        icon: Icons.block_rounded,
      );
    }
    if (stock == null) {
      return _Chip(
        label: AppStrings.orderStockUnknown,
        color: AppColors.muted,
        soft: AppColors.surfaceTint,
        icon: Icons.help_outline_rounded,
      );
    }
    final ask = _qtyLabel(item.quantity);
    final have = _qtyLabel(stock);
    if (item.stockOk) {
      return _Chip(
        label: 'Asked $ask · $have ${item.unit} in stock',
        color: AppColors.success,
        soft: AppColors.successSoft,
        icon: Icons.check_circle_outline_rounded,
      );
    }
    final short = _qtyLabel(item.shortfall);
    return _Chip(
      label: 'Asked $ask · in stock $have · short $short',
      color: AppColors.warning,
      soft: AppColors.warningSoft,
      icon: Icons.warning_amber_rounded,
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
  final IconData icon;

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
          Icon(icon, size: AppSizes.iconSm, color: color),
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
            label: AppStrings.orderTotalsSubtotal,
            value: currency.format(subtotal),
          ),
          _TotalLine(
            label: AppStrings.orderTotalsTax,
            value: currency.format(tax),
            muted: true,
          ),
          _TotalLine(
            label: AppStrings.orderTotalsDiscount,
            value: '−${currency.format(discount)}',
            muted: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.xs),
            child: Divider(height: 1, color: AppColors.hairline),
          ),
          _TotalLine(
            label: AppStrings.orderTotalsTotal,
            value: currency.format(total),
            emphasis: true,
          ),
          if (order.isPending && order.hasStockShortfall) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              AppStrings.orderPartialFulfillFootnote,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
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
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
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
      color: selected ? AppColors.black : AppColors.surfaceTint,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: AppSizes.sm),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? AppColors.white : AppColors.black,
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: AppSizes.iconHuge, color: AppColors.muted),
            const SizedBox(height: AppSizes.md),
            Text(
              AppStrings.error,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

String _qtyLabel(double q) =>
    q.truncateToDouble() == q ? q.toInt().toString() : q.toStringAsFixed(2);

/// Modal bottom sheet replacement for the old confirm dialog. Same
/// copy + same destructive-tone fallback when a shortfall is detected;
/// just a sheet so it composes with the rest of the page's modal style.
class _ConfirmOrderSheet extends StatelessWidget {
  const _ConfirmOrderSheet({required this.shortfall});
  final bool shortfall;

  @override
  Widget build(BuildContext context) {
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
                  ? 'Stock looks short — confirm anyway?'
                  : AppStrings.confirmOrderTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
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
                    side: const BorderSide(color: AppColors.warning),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: AppSizes.iconMd),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        'Some items have less stock than the customer asked '
                        'for. The draft invoice will fail to post when you '
                        'try to confirm it.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              AppStrings.confirmOrderBody,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.huge),
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                    child: const Text('Not yet'),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          shortfall ? AppColors.warning : AppColors.brand,
                      minimumSize: const Size.fromHeight(AppSizes.huge),
                    ),
                    child: const Text(AppStrings.confirmOrder),
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
  String? _selectedReason;

  static const _reasons = [
    AppStrings.orderDeclineReasonOutOfStock,
    AppStrings.orderDeclineReasonClosed,
    AppStrings.orderDeclineReasonPriceChanged,
    AppStrings.orderDeclineReasonOther,
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pickReason(String r) {
    setState(() {
      _selectedReason = r;
      if (r == AppStrings.orderDeclineReasonOther) {
        _ctrl.clear();
      } else {
        _ctrl.text = r;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
              AppStrings.declineOrderTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              AppStrings.declineOrderBody,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: AppSizes.md),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final r in _reasons)
                  _ReasonChip(
                    label: r,
                    selected: _selectedReason == r,
                    onTap: () => _pickReason(r),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppStrings.declineOrderNoteHint,
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
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                    child: const Text('Keep'),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      (ok: true, note: _ctrl.text),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      minimumSize: const Size.fromHeight(AppSizes.huge),
                    ),
                    child: const Text(AppStrings.declineOrder),
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
          color: AppColors.brandSoft,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.brand),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_outlined,
                  size: AppSizes.iconSm,
                  color: AppColors.brandStrong,
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  drafts.length == 1
                      ? '1 stock draft pending'
                      : '${drafts.length} stock drafts pending',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Confirm to post the stock — until then the shortfall stays.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.brandStrong),
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
                const Divider(height: 1, color: AppColors.hairline),
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
                  'Draft invoice #${draft.invoiceId}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open draft',
            onPressed: isConfirming
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InvoiceDetailPage(invoiceId: draft.invoiceId),
                      ),
                    ),
            icon: const Icon(Icons.open_in_new_rounded, size: AppSizes.iconMd),
          ),
          const SizedBox(width: AppSizes.xs),
          FilledButton.icon(
            onPressed: isConfirming ? null : onConfirm,
            icon: isConfirming
                ? const SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: AppSizes.iconSm),
            label: const Text('Confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            ),
          ),
          IconButton(
            tooltip: 'Hide',
            onPressed: isConfirming ? null : onDismiss,
            icon: const Icon(Icons.close_rounded, size: AppSizes.iconSm),
          ),
        ],
      ),
    );
  }
}
