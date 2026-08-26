import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/addresses_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/edit_address_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/cart_item.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/coupons/data/datasources/coupons_remote_data_source.dart';
import 'package:shopxy_customer/features/coupons/domain/entities/coupon.dart';
import 'package:shopxy_customer/features/payments/razorpay_checkout.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/order_detail_page.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/gst/presentation/pages/gst_details_page.dart';
import 'package:shopxy_customer/features/gst/presentation/providers/gst_profile_provider.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_dialog.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/widgets/shop_chip.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

enum _PayAttemptOutcome { paid, pendingConfirmation, dismissed, failed }

class _CheckoutPageState extends State<CheckoutPage> {
  String? _selectedAddressId;
  static const double _deliveryStandard = 0;

  CouponPreview? _appliedCoupon;

  bool _payOnline = false;

  bool _claimGst = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoApply());
  }

  Future<void> _tryAutoApply() async {
    if (!mounted) return;
    if (_appliedCoupon?.ok == true) return;
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;
    try {
      final preview = await context.read<CouponsRemoteDataSource>().autoApply(
        subtotal: cart.itemsTotal,
        shopIds: cart.shopIds,
      );
      if (!mounted) return;
      if (preview.ok) {
        setState(() => _appliedCoupon = preview);
      }
    } catch (_) {
    }
  }

  Future<void> _pickAddress() async {
    final addresses = context.read<AddressesProvider>().items;
    if (addresses.isEmpty) {
      await _addAddress();
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: AppShapes.squircleTop(AppSizes.radiusLg),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Grabber(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.sm,
                  AppSizes.lg,
                  AppSizes.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose a delivery address',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.extraBold,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in addresses)
                      _AddressPickerRow(
                        address: a,
                        selected: a.id == _selectedAddressId,
                        onTap: () => Navigator.of(sheetCtx).pop(a.id),
                      ),
                    const Divider(height: 1, color: AppColors.hairline),
                    ListTile(
                      leading: const AppIcon(
                        AppIcons.addLocationAltOutlined,
                        color: AppColors.brandStrong,
                      ),
                      title: const Text(
                        'Add a new address',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _addAddress();
                      },
                    ),
                    ListTile(
                      leading: const AppIcon(AppIcons.settingsOutlined),
                      title: const Text('Manage addresses'),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddressesPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSizes.lg),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedAddressId = picked);
    }
  }

  Future<void> _addAddress() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditAddressPage()));
    if (created != true || !mounted) return;
    await context.read<AddressesProvider>().load();
    if (!mounted) return;
    final items = context.read<AddressesProvider>().items;
    if (items.isNotEmpty) {
      setState(() => _selectedAddressId = items.first.id);
    }
  }

  Future<void> _applyCoupon(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return;
    final cart = context.read<CartProvider>();
    final ds = context.read<CouponsRemoteDataSource>();
    final subtotal = cart.itemsTotal;
    final shopIds = cart.shopIds;
    try {
      final preview = await ds.validate(
        code: code,
        subtotal: subtotal,
        shopIds: shopIds,
      );
      if (!mounted) return;
      setState(() => _appliedCoupon = preview.ok ? preview : null);
      if (!preview.ok) {
        showAppSnackbar(
          context,
          message: preview.message ?? 'That code isn\'t valid right now',
          tone: AppSnackbarTone.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: friendlyError(
          e,
          fallback: 'Could not check that code. Please try again.',
        ),
        tone: AppSnackbarTone.error,
      );
    }
  }

  void _removeCoupon() {
    setState(() => _appliedCoupon = null);
  }

  bool _submitting = false;

  double _currentGrandTotal(CartProvider cart) {
    final subtotal = cart.totalPrice;
    final couponDiscount = _appliedCoupon?.ok == true
        ? (_appliedCoupon!.discount ?? 0).clamp(0, subtotal).toDouble()
        : 0.0;
    return (subtotal + _deliveryStandard - couponDiscount)
        .clamp(0, double.infinity)
        .toDouble();
  }

  Future<void> _placeOrder() async {
    if (_submitting) return;
    if (_selectedAddressId == null) {
      showAppSnackbar(
        context,
        message: 'Add a delivery address to continue',
        tone: AppSnackbarTone.error,
      );
      return;
    }
    final cart = context.read<CartProvider>();
    final grandTotal = _currentGrandTotal(cart);
    if (grandTotal >= 500) {
      final ok = await AppConfirmSheet.show(
        context,
        title: 'Place this order?',
        message:
            'Estimated total ${AppFormat.rupeesPrecise(grandTotal)} — the shop '
            'confirms the final amount when the order is placed. '
            'We double-check larger orders so a stray tap doesn\'t place one. '
            'You can still cancel a per-shop slice from the order detail page '
            'before the merchant confirms it.',
        confirmLabel: 'Place order',
        cancelLabel: 'Review',
      );
      if (!ok || !mounted) return;
      if (_submitting) return;
    }
    setState(() => _submitting = true);
    final result = await cart.placeOrder(
      addressId: _selectedAddressId,
      couponCode: _appliedCoupon?.code,
      claimGst: _claimGst,
    );
    if (!mounted) {
      _submitting = false;
      return;
    }
    setState(() => _submitting = false);
    if (!result.isSuccess) {
      showAppSnackbar(
        context,
        message: _friendlyError(result.error),
        tone: AppSnackbarTone.error,
      );
      return;
    }
    final orderId = result.orderId!;
    // ignore: unawaited_futures
    context.read<OrdersProvider>().load();
    // ignore: unawaited_futures
    context.read<ShopsProvider>().loadShops();

    if (_payOnline) {
      final outcome = await _startOnlinePayment(orderId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: orderId)),
      );
      final (message, tone) = switch (outcome) {
        _PayAttemptOutcome.paid => (
          'Payment successful',
          AppSnackbarTone.success,
        ),
        _PayAttemptOutcome.pendingConfirmation => (
          'Payment received — being confirmed. This can take a minute.',
          AppSnackbarTone.info,
        ),
        _PayAttemptOutcome.dismissed => (
          'Payment not completed — your order is placed. Use "Pay Now" below whenever you\'re ready.',
          AppSnackbarTone.info,
        ),
        _PayAttemptOutcome.failed => (
          'Payment didn\'t go through — your order is placed. You can retry with "Pay Now" below.',
          AppSnackbarTone.error,
        ),
      };
      showAppSnackbar(context, message: message, tone: tone);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: orderId)),
    );
    if (result.shopOrderCount > 1) {
      showAppSnackbar(
        context,
        message: 'Order placed — ${result.shopOrderCount} shops will fulfil it',
        tone: AppSnackbarTone.success,
      );
    }
  }

  Future<_PayAttemptOutcome> _startOnlinePayment(String orderId) async {
    try {
      final cart = context.read<CartProvider>();
      final checkout = await cart.payForOrder(orderId);
      final result = await RazorpayCheckout().open(
        clientParams: checkout.clientParams,
        description: 'Order #$orderId',
      );
      if (result.isSuccess) {
        try {
          final status = await cart.syncOrderPayment(orderId);
          return status == 'PAID'
              ? _PayAttemptOutcome.paid
              : _PayAttemptOutcome.pendingConfirmation;
        } catch (_) {
          return _PayAttemptOutcome.pendingConfirmation;
        }
      }
      return result.outcome == RazorpayOutcome.dismissed
          ? _PayAttemptOutcome.dismissed
          : _PayAttemptOutcome.failed;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[checkout] online payment failed: $e\n$st');
      }
      if (mounted) {
        showAppSnackbar(
          context,
          message: friendlyError(e, fallback: 'Could not start the payment.'),
          tone: AppSnackbarTone.error,
        );
      }
      return _PayAttemptOutcome.failed;
    }
  }

  Widget _buildPaymentMethod() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        children: [
          _payOption(
            title: 'Cash on Delivery',
            subtitle: 'Pay the shop when your order arrives.',
            value: false,
          ),
          const SizedBox(height: AppSizes.sm),
          _payOption(
            title: 'Pay Online',
            subtitle: 'UPI, cards & netbanking via Razorpay.',
            value: true,
          ),
        ],
      ),
    );
  }

  Widget _payOption({
    required String title,
    required String subtitle,
    required bool value,
  }) {
    final selected = _payOnline == value;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: () => setState(() => _payOnline = value),
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: ShapeDecoration(
            color: AppColors.white,
            shape: AppShapes.squircle(
              AppSizes.radiusMd,
              side: BorderSide(
                color: selected ? AppColors.brand : AppColors.hairline,
                width: selected ? 1.5 : 1,
              ),
            ),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: AppIcon(
                  selected
                      ? AppIcons.radioButtonCheckedRounded
                      : AppIcons.radioButtonUncheckedRounded,
                  color: selected ? AppColors.brand : AppColors.subtle,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.extraBold
                          .copyWith(
                            color: selected ? AppColors.brand : AppColors.black,
                          ),
                    ),
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(String? code) {
    switch (code) {
      case 'OWN_SHOP_ITEM':
        return "You can't order from your own shop";
      case 'SHOP_NOT_FOUND':
        return 'One of the shops in your cart is no longer available';
      case 'CROSS_SHOP_ITEM':
        return 'Cart had a wrong shop attribution — please re-add the items';
      case 'GST_PROFILE_MISSING':
        return 'Add your GSTIN under Profile → GST details before claiming '
            'input credit';
      case 'PRODUCT_INACTIVE':
        return 'One of the items is no longer available';
      case 'PRODUCT_MISSING':
        return 'One of the items was removed by the merchant';
      case 'ADDRESS_NOT_OWNED':
        return "That address isn't valid for this account";
      case 'EMPTY_CART':
        return 'Your cart is empty';
      case 'BAD_QTY':
        return 'Invalid quantity';
      case null:
        return 'Could not place order';
      default:
        return code;
    }
  }

  void _ensureDefault(List<UserAddress> addresses) {
    if (_selectedAddressId != null || addresses.isEmpty) return;
    final primary = addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => addresses.first,
    );
    _selectedAddressId = primary.id;
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final addressesProvider = context.watch<AddressesProvider>();
    final addresses = addressesProvider.items;
    _ensureDefault(addresses);
    final selected = addresses.cast<UserAddress?>().firstWhere(
      (a) => a?.id == _selectedAddressId,
      orElse: () => null,
    );

    final subtotal = cart.totalPrice;
    final mrpTotal = cart.mrpTotal;
    final productSavings = (mrpTotal - subtotal)
        .clamp(0, double.infinity)
        .toDouble();
    final couponDiscount = _appliedCoupon?.ok == true
        ? (_appliedCoupon!.discount ?? 0).clamp(0, subtotal).toDouble()
        : 0.0;
    final afterCoupon = (subtotal + _deliveryStandard - couponDiscount)
        .clamp(0, double.infinity)
        .toDouble();
    final totalSavings = productSavings + couponDiscount;
    final grandTotal = afterCoupon;

    final taxBreakup = _GstBreakup.fromLines(cart.lines);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSizes.lg),
                children: [
                  _StepStrip(),
                  _SectionLabel(
                    label: 'DELIVER TO',
                    trailing: selected == null
                        ? null
                        : TextButton(
                            onPressed: _pickAddress,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.sm,
                              ),
                            ),
                            child: Text(
                              'Change',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppColors.brandStrong,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                  ),
                  if (addressesProvider.isLoading && addresses.isEmpty)
                    const _LoadingCard()
                  else if (addressesProvider.error != null && addresses.isEmpty)
                    _AddressErrorCard(onRetry: () => addressesProvider.load())
                  else if (selected == null)
                    _AddAddressCard(onTap: _pickAddress)
                  else
                    _SelectedAddressCard(address: selected),
                  const SizedBox(height: AppSizes.lg),
                  if (selected != null) ...[
                    const _SectionLabel(label: 'ESTIMATED DELIVERY'),
                    const _DeliveryEstimateCard(),
                    const SizedBox(height: AppSizes.lg),
                  ],
                  _SectionLabel(
                    label:
                        'ORDER ITEMS · ${cart.lineCount} ${cart.lineCount == 1 ? 'item' : 'items'}',
                  ),
                  if (cart.linesByShop.length > 1)
                    _MultiShopBanner(shopCount: cart.linesByShop.length),
                  _ItemsByShop(lines: cart.lines),
                  const SizedBox(height: AppSizes.lg),
                  const _SectionLabel(label: 'OFFERS'),
                  _CouponCard(
                    coupon: _appliedCoupon,
                    onApply: _applyCoupon,
                    onRemove: _removeCoupon,
                  ),
                  const SizedBox(height: AppSizes.lg),
                  const _SectionLabel(label: 'GST INPUT CREDIT'),
                  _GstClaimCard(
                    lines: cart.lines,
                    claiming: _claimGst,
                    onChanged: (v) => setState(() => _claimGst = v),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  const _SectionLabel(label: 'PAYMENT METHOD'),
                  _buildPaymentMethod(),
                  const SizedBox(height: AppSizes.lg),
                  const _SectionLabel(label: 'PRICE DETAILS'),
                  _PriceCard(
                    itemsTotal: subtotal,
                    mrpTotal: mrpTotal,
                    productSavings: productSavings,
                    deliveryStandard: _deliveryStandard,
                    grandTotal: grandTotal,
                    couponDiscount: couponDiscount,
                    taxBreakup: taxBreakup,
                  ),
                  if (totalSavings > 0) ...[
                    const SizedBox(height: AppSizes.sm),
                    _SavingsBanner(amount: totalSavings),
                  ],
                  const SizedBox(height: AppSizes.lg),
                  const _TrustFooter(),
                ],
              ),
            ),
            _Footer(
              total: grandTotal,
              savings: totalSavings,
              isPlacing: cart.isPlacing,
              canPlace: selected != null && !cart.isPlacing,
              blockedHint: selected == null ? 'Add a delivery address' : null,
              onBlockedTap: _pickAddress,
              onPlace: _placeOrder,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(bottom: BorderSide(color: AppColors.hairline, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sm,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const AppIcon(AppIcons.arrowBackRounded),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Checkout',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                  ],
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  'Review your order and place it',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      child: Row(
        children: [
          _dot(context, 1, 'Address', active: true),
          _bar(true),
          _dot(context, 2, 'Review', active: true),
          _bar(false),
          _dot(context, 3, 'Payment', active: false),
        ],
      ),
    );
  }

  Widget _dot(
    BuildContext context,
    int n,
    String label, {
    required bool active,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSizes.xxl,
          height: AppSizes.xxl,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.brandStrong : AppColors.heroPanel,
          ),
          alignment: Alignment.center,
          child: Text(
            '$n',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? AppColors.white : AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active ? AppColors.brandStrong : AppColors.subtle,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _bar(bool active) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(bottom: AppSizes.xl),
      height: 2,
      color: active ? AppColors.brandStrong : AppColors.hairline,
    ),
  );
}

class _GstClaimCard extends StatelessWidget {
  const _GstClaimCard({
    required this.lines,
    required this.claiming,
    required this.onChanged,
  });

  final List<CartItem> lines;
  final bool claiming;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gst = context.watch<GstProfileProvider>();

    final unregistered = <String>{
      for (final l in lines)
        if (!l.product.shopGstRegistered) l.product.shopName ?? 'One seller',
    };
    final anyRegistered = lines.any((l) => l.product.shopGstRegistered);

    if (!gst.canClaimGst) {
      return _Shell(
        child: _Message(
          key: const Key('gst-claim-add-profile'),
          title: 'Buying for a business?',
          body:
              'Add your GSTIN and we can ask GST-registered sellers to '
              "invoice this order in your business's name.",
          action: 'Add GST details',
          onAction: () async {
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const GstDetailsPage()));
          },
        ),
      );
    }

    if (!anyRegistered) {
      return _Shell(
        child: _Message(
          key: const Key('gst-claim-unavailable'),
          title: 'No tax invoice for this order',
          body:
              'None of the sellers in this cart are registered under GST, '
              'so no GST is charged and there is nothing to claim.',
        ),
      );
    }

    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claim input credit',
                      style: theme.textTheme.bodyMedium?.extraBold,
                    ),
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      'Invoice this order to ${gst.profile.legalName} '
                      '(${gst.profile.gstin}).',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Switch.adaptive(
                key: const Key('gst-claim-switch'),
                value: claiming,
                onChanged: onChanged,
              ),
            ],
          ),
          if (claiming && unregistered.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              unregistered.length == 1
                  ? '${unregistered.first} is not registered under GST, so '
                        'that part of your order gets a bill of supply with no '
                        'GST to claim.'
                  : '${unregistered.length} sellers in this cart are not '
                        'registered under GST, so their part of the order gets '
                        'a bill of supply with no GST to claim.',
              key: const Key('gst-claim-partial-warning'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
    padding: const EdgeInsets.all(AppSizes.md),
    decoration: ShapeDecoration(
      color: AppColors.white,
      shape: AppShapes.squircle(AppSizes.radiusMd),
    ),
    child: child,
  );
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.bodyMedium?.extraBold),
        const SizedBox(height: AppSizes.xxs),
        Text(
          body,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.muted,
            height: 1.35,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: AppSizes.sm),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.brand,
            ),
            child: Text(
              action!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.trailing});
  final String label;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
    child: Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: const Center(
        child: SizedBox(
          width: AppSizes.iconLg,
          height: AppSizes.iconLg,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
  );
}

class _SelectedAddressCard extends StatelessWidget {
  const _SelectedAddressCard({required this.address});
  final UserAddress address;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            decoration: ShapeDecoration(
              color: AppColors.brandSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const AppIcon(
              AppIcons.locationOnRounded,
              color: AppColors.brandStrong,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.xs,
                  children: [
                    Text(
                      address.fullName,
                      style: Theme.of(context).textTheme.bodyMedium?.extraBold,
                    ),
                    if (address.label != null)
                      _LabelPill(text: address.label!, tone: _Tone.neutral),
                    if (address.isDefault)
                      const _LabelPill(text: 'DEFAULT', tone: _Tone.success),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  address.oneLine,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.black,
                    height: 1.4,
                  ),
                ),
                if (address.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.xs),
                    child: Row(
                      children: [
                        const AppIcon(
                          AppIcons.phoneRounded,
                          size: AppSizes.iconSm,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: AppSizes.xs),
                        Text(
                          address.phone,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
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

enum _Tone { neutral, success }

class _LabelPill extends StatelessWidget {
  const _LabelPill({required this.text, required this.tone});
  final String text;
  final _Tone tone;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _Tone.neutral => (AppColors.heroPanel, AppColors.black),
      _Tone.success => (AppColors.successSoft, AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _AddAddressCard extends StatelessWidget {
  const _AddAddressCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.brand, width: 1.2),
        ),
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                const AppIcon(
                  AppIcons.addLocationAltOutlined,
                  color: AppColors.brandStrong,
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add a delivery address',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.extraBold,
                      ),
                      const SizedBox(height: AppSizes.xxs),
                      Text(
                        'We need somewhere to send your order.',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const AppIcon(
                  AppIcons.chevronRightRounded,
                  color: AppColors.subtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressErrorCard extends StatelessWidget {
  const _AddressErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Row(
        children: [
          const AppIcon(AppIcons.cloudOffRounded, color: AppColors.muted),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              "Couldn't load your addresses. Check your connection and retry.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          AppButton.secondary(
            label: 'Retry',
            size: AppButtonSize.sm,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _AddressPickerRow extends StatelessWidget {
  const _AddressPickerRow({
    required this.address,
    required this.selected,
    required this.onTap,
  });
  final UserAddress address;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AppIcon(
                selected
                    ? AppIcons.radioButtonCheckedRounded
                    : AppIcons.radioButtonUncheckedRounded,
                color: selected ? AppColors.brandStrong : AppColors.subtle,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.fullName,
                    style: Theme.of(context).textTheme.bodyMedium?.extraBold,
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    address.oneLine,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryEstimateCard extends StatelessWidget {
  const _DeliveryEstimateCard();
  @override
  Widget build(BuildContext context) {
    final eta = DateTime.now().add(const Duration(days: 3));
    final etaLabel = DateFormat('EEE, d MMM').format(eta);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            decoration: ShapeDecoration(
              color: AppColors.successSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const AppIcon(
              AppIcons.localShippingOutlined,
              color: AppColors.success,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arriving by $etaLabel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  'Standard delivery · merchant confirms a final date',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsByShop extends StatelessWidget {
  const _ItemsByShop({required this.lines});
  final List<CartItem> lines;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<CartItem>>{};
    final order = <String>[];
    for (final line in lines) {
      final shopId = line.product.shopId ?? '';
      if (!groups.containsKey(shopId)) order.add(shopId);
      (groups[shopId] ??= []).add(line);
    }
    return Column(
      children: [
        for (var i = 0; i < order.length; i++) ...[
          if (i != 0) const SizedBox(height: AppSizes.md),
          _ShopGroupCard(
            shopName: groups[order[i]]!.first.product.shopName,
            lines: groups[order[i]]!,
            showHeader: order.length > 1,
            orderIndex: i + 1,
            orderCount: order.length,
          ),
        ],
      ],
    );
  }
}

class _ShopGroupCard extends StatelessWidget {
  const _ShopGroupCard({
    required this.shopName,
    required this.lines,
    required this.showHeader,
    required this.orderIndex,
    required this.orderCount,
  });
  final String? shopName;
  final List<CartItem> lines;
  final bool showHeader;
  final int orderIndex;
  final int orderCount;

  @override
  Widget build(BuildContext context) {
    final subtotal = lines.fold<double>(0, (s, l) => s + l.lineTotal);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                AppSizes.md,
                AppSizes.md,
                0,
              ),
              child: Row(
                children: [
                  Expanded(child: ShopChip(shopName: shopName)),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    'Order $orderIndex of $orderCount',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          if (showHeader && shopName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                AppSizes.xs,
                AppSizes.md,
                0,
              ),
              child: Row(
                children: [
                  const AppIcon(
                    AppIcons.storefrontOutlined,
                    size: 14,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Expanded(
                    child: Text(
                      'Sold by $shopName · seller details & GSTIN on the shop page',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (showHeader)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
              child: _RowDivider(),
            ),
          for (var i = 0; i < lines.length; i++) ...[
            if (i != 0) const _RowDivider(),
            _ItemRow(line: lines[i]),
          ],
          if (showHeader) ...[
            const _RowDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Shop subtotal',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AppPriceText.precise(
                    subtotal,
                    fontWeight: FontWeight.w800,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSizes.md),
    child: Divider(height: 1, color: AppColors.hairline),
  );
}

class _MultiShopBanner extends StatelessWidget {
  const _MultiShopBanner({required this.shopCount});
  final int shopCount;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        0,
        AppSizes.lg,
        AppSizes.md,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: ShapeDecoration(
        color: AppColors.infoSoft,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const AppIcon(
            AppIcons.storefrontOutlined,
            size: AppSizes.iconMd,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Your cart has items from $shopCount shops — '
              "we'll create $shopCount separate orders, one per shop.",
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.info,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line});
  final CartItem line;
  @override
  Widget build(BuildContext context) {
    final p = line.product;
    final qtyStr = line.quantity == line.quantity.roundToDouble()
        ? line.quantity.toInt().toString()
        : line.quantity.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
            child: Container(
              width: AppSizes.productThumbSize,
              height: AppSizes.productThumbSize,
              color: AppColors.heroPanel,
              child: p.imageUrl == null
                  ? const AppIcon(
                      AppIcons.imageOutlined,
                      color: AppColors.muted,
                      size: AppSizes.iconMd,
                    )
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (p.shopName != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ShopChip(shopName: p.shopName, dense: true),
                  ),
                ],
                const SizedBox(height: AppSizes.xs),
                Wrap(
                  spacing: AppSizes.sm,
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
                        'Qty $qtyStr',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      p.unit,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          AppPriceText.precise(
            line.lineTotal,
            fontWeight: FontWeight.w800,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _GstBreakup {
  const _GstBreakup({
    required this.taxableValue,
    required this.taxTotal,
    required this.perRate,
  });

  final double taxableValue;
  final double taxTotal;

  final List<({double rate, double tax})> perRate;

  factory _GstBreakup.fromLines(List<CartItem> lines) {
    final byRate = <double, double>{};
    for (final l in lines) {
      final inclusive = l.lineTotal;
      if (inclusive <= 0) continue;
      final rate = l.product.taxPercent > 0 ? l.product.taxPercent : 0.0;
      byRate[rate] = (byRate[rate] ?? 0) + inclusive;
    }
    var taxable = 0.0;
    var tax = 0.0;
    final rows = <({double rate, double tax})>[];
    byRate.forEach((rate, inclusive) {
      final lineTaxable = rate > 0 ? inclusive * 100 / (100 + rate) : inclusive;
      final lineTax = inclusive - lineTaxable;
      taxable += lineTaxable;
      tax += lineTax;
      if (rate > 0) rows.add((rate: rate, tax: lineTax));
    });
    rows.sort((a, b) => a.rate.compareTo(b.rate));
    return _GstBreakup(taxableValue: taxable, taxTotal: tax, perRate: rows);
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.itemsTotal,
    required this.mrpTotal,
    required this.productSavings,
    required this.deliveryStandard,
    required this.grandTotal,
    required this.taxBreakup,
    this.couponDiscount = 0,
  });
  final double itemsTotal;
  final double mrpTotal;
  final double productSavings;
  final double deliveryStandard;
  final double grandTotal;
  final _GstBreakup taxBreakup;
  final double couponDiscount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          if (productSavings > 0)
            _PriceRow(
              label: 'Items (MRP)',
              value: mrpTotal,
              valueStrike: true,
              valueColor: AppColors.muted,
            ),
          _PriceRow(label: 'Items total', value: itemsTotal),
          if (productSavings > 0)
            _PriceRow(
              label: 'Product discount',
              negative: productSavings,
              valueColor: AppColors.success,
            ),
          _PriceRow(
            label: 'Delivery',
            valueLabel: deliveryStandard == 0 ? 'FREE' : null,
            value: deliveryStandard == 0 ? null : deliveryStandard,
            valueColor: AppColors.success,
          ),
          if (couponDiscount > 0)
            _PriceRow(
              label: 'Coupon',
              negative: couponDiscount,
              valueColor: AppColors.success,
            ),
          const Divider(height: AppSizes.lg, color: AppColors.hairline),
          _PriceRow(
            label: 'Total payable (estimate)',
            value: grandTotal,
            bold: true,
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.xs),
            child: Text(
              'Estimated — the shop confirms the final amount when your order is placed.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (taxBreakup.taxTotal > 0) ...[
            const Divider(height: AppSizes.lg, color: AppColors.hairline),
            _PriceRow(
              label: 'Taxable value',
              value: taxBreakup.taxableValue,
              valueColor: AppColors.muted,
            ),
            for (final r in taxBreakup.perRate)
              _PriceRow(
                label: 'GST @ ${_fmtRate(r.rate)}% (incl.)',
                value: r.tax,
                valueColor: AppColors.muted,
              ),
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xs),
              child: Text(
                'Prices are inclusive of all taxes.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();
}

class _CouponCard extends StatefulWidget {
  const _CouponCard({
    required this.coupon,
    required this.onApply,
    required this.onRemove,
  });
  final CouponPreview? coupon;
  final Future<void> Function(String code) onApply;
  final VoidCallback onRemove;

  @override
  State<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends State<_CouponCard> {
  late final TextEditingController _ctrl;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.coupon?.code ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await widget.onApply(_ctrl.text);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.coupon;
    final applied = c?.ok == true;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(
            color: applied ? AppColors.brand : AppColors.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          AppIcon(
            AppIcons.localOfferOutlined,
            color: applied ? AppColors.brand : AppColors.muted,
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: applied
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c!.autoApplied
                                  ? 'Auto-applied · ${c.code}'
                                  : '${c.code} applied',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w800,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.autoApplied)
                            Container(
                              margin: const EdgeInsets.only(left: AppSizes.sm),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.sm,
                                vertical: 1,
                              ),
                              decoration: ShapeDecoration(
                                color: AppColors.brand,
                                shape: AppShapes.squircle(AppSizes.radiusSm),
                              ),
                              child: Text(
                                'OFFER',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      if (c.discount != null)
                        Text(
                          '${AppFormat.rupees(c.discount!)} off',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  )
                : TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Enter coupon code',
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
          applied
              ? TextButton(
                  onPressed: () {
                    _ctrl.clear();
                    widget.onRemove();
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                  child: const Text('Remove'),
                )
              : FilledButton(
                  onPressed: _applying ? null : _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.black,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg,
                      vertical: AppSizes.md,
                    ),
                  ),
                  child: _applying
                      ? const SizedBox(
                          width: AppSizes.iconSm,
                          height: AppSizes.iconSm,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          'Apply',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.extraBold,
                        ),
                ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    this.value,
    this.valueLabel,
    this.valueColor,
    this.bold = false,
    this.valueStrike = false,
    this.negative,
  });
  final String label;
  final double? value;
  final String? valueLabel;
  final Color? valueColor;
  final bool bold;
  final bool valueStrike;
  final double? negative;

  @override
  Widget build(BuildContext context) {
    final col = valueColor ?? AppColors.black;
    final theme = Theme.of(context);
    Widget val;
    if (valueLabel != null) {
      val = Text(
        valueLabel!,
        style: (bold ? theme.textTheme.titleMedium : theme.textTheme.bodySmall)
            ?.copyWith(color: col, fontWeight: FontWeight.w800),
      );
    } else if (negative != null) {
      val = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '− ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
          AppPriceText.precise(
            negative!,
            color: col,
            fontWeight: FontWeight.w800,
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    } else {
      val = AppPriceText.precise(
        value ?? 0,
        color: col,
        fontWeight: FontWeight.w800,
        strikethrough: valueStrike,
        style: bold ? theme.textTheme.titleMedium : theme.textTheme.bodySmall,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  (bold
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall)
                      ?.copyWith(
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

class _SavingsBanner extends StatelessWidget {
  const _SavingsBanner({required this.amount});
  final double amount;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: ShapeDecoration(
        color: AppColors.successSoft,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const AppIcon(
            AppIcons.savingsOutlined,
            color: AppColors.success,
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Wrap(
              children: [
                Text(
                  "You'll save ",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppPriceText.precise(
                  amount,
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  ' on this order',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
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

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                child: _TrustPill(
                  icon: AppIcons.lockOutlineRounded,
                  label: 'Secure checkout',
                ),
              ),
              SizedBox(width: AppSizes.sm),
              Expanded(
                child: _TrustPill(
                  icon: AppIcons.replayRounded,
                  label: 'Cancel per shop policy',
                ),
              ),
              SizedBox(width: AppSizes.sm),
              Expanded(
                child: _TrustPill(
                  icon: AppIcons.supportAgentRounded,
                  label: 'In-app support',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text(
              'By placing your order, you agree to our terms. Pricing and availability may be re-confirmed by the shop.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label});
  final AppIconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.sm,
      ),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Column(
        children: [
          AppIcon(icon, size: AppSizes.iconMd, color: AppColors.brandStrong),
          const SizedBox(height: AppSizes.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSizes.sm),
    child: Container(
      width: AppSizes.handleWidth,
      height: AppSizes.handleHeight,
      decoration: BoxDecoration(
        color: AppColors.hairline,
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusXs),
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.total,
    required this.savings,
    required this.isPlacing,
    required this.canPlace,
    required this.onPlace,
    this.blockedHint,
    this.onBlockedTap,
  });
  final double total;
  final double savings;
  final bool isPlacing;
  final bool canPlace;
  final VoidCallback onPlace;

  final String? blockedHint;
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Material(
      color: AppColors.white,
      elevation: 12,
      shadowColor: AppColors.black.withValues(alpha: 0.15),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSizes.md,
          AppSizes.sm,
          AppSizes.md,
          AppSizes.sm + bottomPad,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (blockedHint != null && !isPlacing) ...[
              InkWell(
                onTap: onBlockedTap,
                borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(
                        AppIcons.infoOutlineRounded,
                        size: AppSizes.iconSm,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Flexible(
                        child: Text(
                          blockedHint!,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.xs),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total payable (est.)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      AppPriceText.precise(
                        total,
                        fontWeight: FontWeight.w800,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (savings > 0)
                        Wrap(
                          children: [
                            Text(
                              'You save ',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            AppPriceText.precise(
                              savings,
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 6,
                  child: AppButton.primary(
                    label: 'Place order',
                    onPressed: canPlace ? onPlace : null,
                    isLoading: isPlacing,
                    trailingIcon: AppIcons.arrowForwardRounded,
                    fullWidth: true,
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
