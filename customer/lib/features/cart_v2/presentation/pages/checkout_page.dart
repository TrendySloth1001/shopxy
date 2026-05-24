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
import 'package:shopxy_customer/features/home_v2/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/order_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Checkout page — full Amazon/Flipkart-style rebuild (May 2026,
/// build3). Built on a Column { Header, Expanded(Body), Footer }
/// shell so the layout regions can never reorder. A "BUILD 3" pill
/// in the header is the canary that confirms this file is the one
/// running on the device.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  int? _selectedAddressId;
  static const double _deliveryStandard = 0;
  static const double _deliveryStrike = 49;

  Future<void> _pickAddress() async {
    final addresses = context.read<AddressesProvider>().items;
    if (addresses.isEmpty) {
      await _addAddress();
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
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
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose a delivery address',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
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
                      leading: const Icon(Icons.add_location_alt_outlined,
                          color: AppColors.brandStrong),
                      title: const Text('Add a new address',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _addAddress();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Manage addresses'),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const AddressesPage()),
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
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditAddressPage()),
    );
    if (created != true || !mounted) return;
    await context.read<AddressesProvider>().load();
    if (!mounted) return;
    final items = context.read<AddressesProvider>().items;
    if (items.isNotEmpty) {
      setState(() => _selectedAddressId = items.first.id);
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddressId == null) {
      showAppSnackbar(
        context,
        message: 'Add a delivery address to continue',
        tone: AppSnackbarTone.error,
      );
      return;
    }
    final cart = context.read<CartProvider>();
    final id = await cart.placeOrder(addressId: _selectedAddressId);
    if (!mounted) return;
    if (id == null) {
      showAppSnackbar(
        context,
        message: cart.error ?? 'Could not place order',
        tone: AppSnackbarTone.error,
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: id)),
    );
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
    final mrpTotal = cart.lines.fold<double>(
      0,
      (s, l) => s + l.product.mrp * l.quantity,
    );
    final productSavings =
        (mrpTotal - subtotal).clamp(0, double.infinity).toDouble();
    final deliverySavings = _deliveryStrike - _deliveryStandard;
    final totalSavings = productSavings + deliverySavings;
    final grandTotal = subtotal + _deliveryStandard;

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
                                  horizontal: AppSizes.sm),
                            ),
                            child: const Text(
                              'Change',
                              style: TextStyle(
                                color: AppColors.brandStrong,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                  if (addressesProvider.isLoading && addresses.isEmpty)
                    const _LoadingCard()
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
                  _ItemsCard(lines: cart.lines),
                  const SizedBox(height: AppSizes.lg),
                  const _SectionLabel(label: 'PAYMENT METHOD'),
                  const _PaymentCard(),
                  const SizedBox(height: AppSizes.lg),
                  const _SectionLabel(label: 'PRICE DETAILS'),
                  _PriceCard(
                    itemsTotal: subtotal,
                    mrpTotal: mrpTotal,
                    productSavings: productSavings,
                    deliveryStandard: _deliveryStandard,
                    deliveryStrike: _deliveryStrike,
                    grandTotal: grandTotal,
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
              onPlace: _placeOrder,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header (replaces Scaffold appBar so layout slots can't swap) ───

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(
          bottom: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sm, AppSizes.sm, AppSizes.lg, AppSizes.md,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
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
                    const Text(
                      'Checkout',
                      style: TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Review your order and place it',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

// ─── Step indicator strip ───────────────────────────────────────────

class _StepStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg, AppSizes.md, AppSizes.lg, 0,
      ),
      child: Row(
        children: [
          _dot(1, 'Address', active: true),
          _bar(true),
          _dot(2, 'Review', active: true),
          _bar(false),
          _dot(3, 'Payment', active: false),
        ],
      ),
    );
  }

  Widget _dot(int n, String label, {required bool active}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.brandStrong : AppColors.heroPanel,
          ),
          alignment: Alignment.center,
          child: Text(
            '$n',
            style: TextStyle(
              color: active ? AppColors.white : AppColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? AppColors.brandStrong : AppColors.subtle,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _bar(bool active) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          height: 2,
          color: active ? AppColors.brandStrong : AppColors.hairline,
        ),
      );
}

// ─── Section primitives ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.trailing});
  final String label;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 11,
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
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
}

// ─── Address ────────────────────────────────────────────────────────

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
            width: 36, height: 36,
            decoration: ShapeDecoration(
              color: AppColors.brandSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.brandStrong, size: 20),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      address.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (address.label != null)
                      _LabelPill(text: address.label!, tone: _Tone.neutral),
                    if (address.isDefault)
                      const _LabelPill(text: 'DEFAULT', tone: _Tone.success),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address.oneLine,
                  style: const TextStyle(
                    color: AppColors.black, fontSize: 13, height: 1.4),
                ),
                if (address.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_rounded,
                            size: 14, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          address.phone,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10,
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
              children: const [
                Icon(Icons.add_location_alt_outlined,
                    color: AppColors.brandStrong),
                SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add a delivery address',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          )),
                      SizedBox(height: 2),
                      Text(
                        'We need somewhere to send your order.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
              ],
            ),
          ),
        ),
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
            horizontal: AppSizes.lg, vertical: AppSizes.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.oneLine,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 13),
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

// ─── Delivery estimate ──────────────────────────────────────────────

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
            width: 36, height: 36,
            decoration: ShapeDecoration(
              color: AppColors.successSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.local_shipping_outlined,
                color: AppColors.success, size: 20),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arriving by $etaLabel',
                  style: const TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Standard delivery · merchant confirms a final date',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Items ──────────────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.lines});
  final List<CartItem> lines;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i != 0) const Divider(height: 1, color: AppColors.hairline),
            _ItemRow(line: lines[i]),
          ],
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
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: Container(
              width: 56, height: 56,
              color: AppColors.heroPanel,
              child: p.imageUrl == null
                  ? const Icon(Icons.image_outlined,
                      color: AppColors.muted, size: 20)
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
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
                        'Qty $qtyStr',
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      p.unit,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
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
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Payment + price ────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard();
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
        children: [
          const Icon(Icons.radio_button_checked_rounded,
              color: AppColors.brandStrong),
          const SizedBox(width: AppSizes.md),
          Container(
            width: 36, height: 36,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.payments_outlined,
                color: AppColors.black, size: 20),
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cash on Delivery',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    )),
                SizedBox(height: 2),
                Text(
                  'Pay the shop when your order arrives.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.itemsTotal,
    required this.mrpTotal,
    required this.productSavings,
    required this.deliveryStandard,
    required this.deliveryStrike,
    required this.grandTotal,
  });
  final double itemsTotal;
  final double mrpTotal;
  final double productSavings;
  final double deliveryStandard;
  final double deliveryStrike;
  final double grandTotal;

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
            strikeBefore:
                deliveryStrike > deliveryStandard ? deliveryStrike : null,
          ),
          const Divider(height: AppSizes.lg, color: AppColors.hairline),
          _PriceRow(
            label: 'Total payable',
            value: grandTotal,
            bold: true,
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
    this.strikeBefore,
  });
  final String label;
  final double? value;
  final String? valueLabel;
  final Color? valueColor;
  final bool bold;
  final bool valueStrike;
  final double? negative;
  final double? strikeBefore;

  @override
  Widget build(BuildContext context) {
    final col = valueColor ?? AppColors.black;
    Widget val;
    if (valueLabel != null) {
      val = Text(
        valueLabel!,
        style: TextStyle(
          color: col,
          fontSize: bold ? 16 : 13,
          fontWeight: FontWeight.w800,
        ),
      );
    } else if (negative != null) {
      val = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('− ',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              )),
          AppPriceText.precise(
            negative!,
            color: col,
            fontWeight: FontWeight.w800,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      );
    } else {
      val = AppPriceText.precise(
        value ?? 0,
        color: col,
        fontWeight: FontWeight.w800,
        strikethrough: valueStrike,
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
          if (strikeBefore != null) ...[
            AppPriceText.precise(
              strikeBefore!,
              color: AppColors.muted,
              strikethrough: true,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 6),
          ],
          val,
        ],
      ),
    );
  }
}

// ─── Savings banner + trust ─────────────────────────────────────────

class _SavingsBanner extends StatelessWidget {
  const _SavingsBanner({required this.amount});
  final double amount;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      decoration: ShapeDecoration(
        color: AppColors.successSoft,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined,
              color: AppColors.success, size: 18),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Wrap(
              children: [
                const Text(
                  "You'll save ",
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                AppPriceText.precise(
                  amount,
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  style: const TextStyle(fontSize: 13),
                ),
                const Text(
                  ' on this order',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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
          horizontal: AppSizes.lg, vertical: AppSizes.sm),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                  child: _TrustPill(
                      icon: Icons.lock_outline_rounded,
                      label: 'Secure checkout')),
              SizedBox(width: AppSizes.sm),
              Expanded(
                  child: _TrustPill(
                      icon: Icons.replay_rounded, label: 'Easy cancel')),
              SizedBox(width: AppSizes.sm),
              Expanded(
                  child: _TrustPill(
                      icon: Icons.support_agent_rounded,
                      label: 'Real support')),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text(
              'By placing your order, you agree to our terms. Pricing and availability may be re-confirmed by the shop.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm, vertical: AppSizes.sm),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.brandStrong),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 11,
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
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: AppColors.hairline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

// ─── Footer (replaces Scaffold bottomNavigationBar) ─────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.total,
    required this.savings,
    required this.isPlacing,
    required this.canPlace,
    required this.onPlace,
  });
  final double total;
  final double savings;
  final bool isPlacing;
  final bool canPlace;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Material(
      color: AppColors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.sm + bottomPad,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              flex: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total payable',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 11)),
                  AppPriceText.precise(
                    total,
                    fontWeight: FontWeight.w800,
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (savings > 0)
                    Wrap(
                      children: [
                        const Text(
                          'You save ',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppPriceText.precise(
                          savings,
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Flexible(
              flex: 6,
              child: AppButton.primary(
                label: 'Place order',
                onPressed: canPlace ? onPlace : null,
                isLoading: isPlacing,
                trailingIcon: Icons.arrow_forward_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
