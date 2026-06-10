import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/shop/data/models/shop.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';

/// Merchant-side editor for the marketplace shop profile. Distinct from
/// the legal/GST shop details on EditProfilePage — those drive invoice
/// headers, while everything here drives how customers see the shop on
/// the marketplace (logo, banner, public name, publish state).
class ShopProfilePage extends StatefulWidget {
  const ShopProfilePage({super.key});

  @override
  State<ShopProfilePage> createState() => _ShopProfilePageState();
}

class _ShopProfilePageState extends State<ShopProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _tagline;
  late final TextEditingController _locationCity;
  late final TextEditingController _locationState;
  late final TextEditingController _returnPolicy;
  late final TextEditingController _shippingPolicy;
  late final TextEditingController _refundPolicy;
  late final TextEditingController _returnWindowDays;
  late final TextEditingController _returnPolicyNote;
  bool _returnsEnabled = false;
  String _refundMode = 'ORIGINAL';
  String _cancellationPolicy = 'UNTIL_SHIPPED';
  String? _logoUrl;
  String? _bannerUrl;
  bool _uploadingLogo = false;
  bool _uploadingBanner = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _tagline = TextEditingController();
    _locationCity = TextEditingController();
    _locationState = TextEditingController();
    _returnPolicy = TextEditingController();
    _shippingPolicy = TextEditingController();
    _refundPolicy = TextEditingController();
    _returnWindowDays = TextEditingController();
    _returnPolicyNote = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopProvider>().load();
    });
  }

  void _hydrate(Shop shop) {
    if (_initialised) return;
    _initialised = true;
    _name.text = shop.name;
    _tagline.text = shop.tagline ?? '';
    _locationCity.text = shop.locationCity ?? '';
    _locationState.text = shop.locationState ?? '';
    _returnPolicy.text = shop.returnPolicy ?? '';
    _shippingPolicy.text = shop.shippingPolicy ?? '';
    _refundPolicy.text = shop.refundPolicy ?? '';
    _returnsEnabled = shop.returnsEnabled;
    _returnWindowDays.text = shop.returnWindowDays.toString();
    _refundMode = shop.refundMode;
    _returnPolicyNote.text = shop.returnPolicyNote ?? '';
    _cancellationPolicy = shop.cancellationPolicy;
    _logoUrl = shop.logoUrl;
    _bannerUrl = shop.bannerUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    _locationCity.dispose();
    _locationState.dispose();
    _returnPolicy.dispose();
    _shippingPolicy.dispose();
    _refundPolicy.dispose();
    _returnWindowDays.dispose();
    _returnPolicyNote.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    const maxBytes = 5 * 1024 * 1024;
    if (file.lengthSync() > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image is larger than 5 MB. Pick a smaller image or crop tighter.',
          ),
        ),
      );
      return;
    }
    setState(() {
      if (isLogo) {
        _uploadingLogo = true;
      } else {
        _uploadingBanner = true;
      }
    });
    final shop = context.read<ShopProvider>();
    final url = await shop.uploadImage(file);
    if (!mounted) return;
    setState(() {
      if (isLogo) {
        _uploadingLogo = false;
        if (url != null) _logoUrl = url;
      } else {
        _uploadingBanner = false;
        if (url != null) _bannerUrl = url;
      }
    });
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shop.error ?? 'Image upload failed')),
      );
    }
  }

  /// Helper — null when the controller's text matches the stored
  /// value (so we don't send a no-op), or the canonical normalised
  /// value (empty string → null clear) when it differs.
  String? _diffText(TextEditingController c, String? stored) {
    final next = c.text.trim().isEmpty ? null : c.text.trim();
    final prev = stored?.trim().isEmpty == true ? null : stored?.trim();
    if (next == prev) return null;
    return next;
  }

  bool _isDirty(Shop shop) {
    return _name.text.trim() != shop.name ||
        _diffText(_tagline, shop.tagline) != null ||
        _diffText(_locationCity, shop.locationCity) != null ||
        _diffText(_locationState, shop.locationState) != null ||
        _diffText(_returnPolicy, shop.returnPolicy) != null ||
        _diffText(_shippingPolicy, shop.shippingPolicy) != null ||
        _diffText(_refundPolicy, shop.refundPolicy) != null ||
        _returnsEnabled != shop.returnsEnabled ||
        (int.tryParse(_returnWindowDays.text.trim()) ??
                shop.returnWindowDays) !=
            shop.returnWindowDays ||
        _refundMode != shop.refundMode ||
        _diffText(_returnPolicyNote, shop.returnPolicyNote) != null ||
        _cancellationPolicy != shop.cancellationPolicy ||
        _logoUrl != shop.logoUrl ||
        _bannerUrl != shop.bannerUrl;
  }

  Future<void> _save(Shop current) async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ShopProvider>();
    final newName = _name.text.trim();

    // For each text field: send the new value when changed, the
    // sentinel `_absent` when not. `_diffText` returns null only when
    // unchanged, so a non-null value means "send this" (including the
    // explicit-null sentinel for clears).
    Object? maybe(String? diff) => diff ?? const Object();

    final newWindowDays = int.tryParse(_returnWindowDays.text.trim());

    final ok = await provider.save(
      name: newName == current.name ? null : newName,
      tagline: maybe(_diffText(_tagline, current.tagline)),
      logoUrl: _logoUrl == current.logoUrl ? const Object() : _logoUrl,
      bannerUrl:
          _bannerUrl == current.bannerUrl ? const Object() : _bannerUrl,
      locationCity: maybe(_diffText(_locationCity, current.locationCity)),
      locationState: maybe(_diffText(_locationState, current.locationState)),
      returnPolicy: maybe(_diffText(_returnPolicy, current.returnPolicy)),
      shippingPolicy:
          maybe(_diffText(_shippingPolicy, current.shippingPolicy)),
      refundPolicy: maybe(_diffText(_refundPolicy, current.refundPolicy)),
      returnsEnabled: _returnsEnabled == current.returnsEnabled
          ? const Object()
          : _returnsEnabled,
      returnWindowDays:
          newWindowDays == null || newWindowDays == current.returnWindowDays
              ? const Object()
              : newWindowDays,
      refundMode:
          _refundMode == current.refundMode ? const Object() : _refundMode,
      returnPolicyNote:
          maybe(_diffText(_returnPolicyNote, current.returnPolicyNote)),
      cancellationPolicy: _cancellationPolicy == current.cancellationPolicy
          ? const Object()
          : _cancellationPolicy,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Shop profile saved' : 'Save failed')),
    );
  }

  Future<void> _togglePublish(Shop shop) async {
    if (shop.isPublished) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unpublish shop?'),
          content: const Text(
            'Customers will stop seeing your shop on the marketplace. Your inventory and orders are unaffected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unpublish'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    if (!mounted) return;
    final ok = await context.read<ShopProvider>().togglePublish(!shop.isPublished);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (!shop.isPublished
                  ? 'Shop is now live on the marketplace'
                  : 'Shop hidden from marketplace')
              : 'Failed to update publish state',
        ),
      ),
    );
  }

  /// Returns true when the user confirms they want to discard
  /// unsaved edits. Used by PopScope to guard the back gesture.
  Future<bool> _confirmDiscard(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          "You have unsaved edits. Leaving now drops them.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShopProvider>();
    final shop = provider.shop;
    final dirty = shop != null && _isDirty(shop);

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!mounted) return;
        // Snapshot the Navigator BEFORE the dialog await so we don't
        // touch context after the gap (lint use_build_context_sync).
        final nav = Navigator.of(context);
        final discard = await _confirmDiscard(context);
        if (discard && mounted) nav.pop();
      },
      child: Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('My Shop'),
        actions: [
          if (dirty)
            TextButton(
              onPressed: provider.isSaving ? null : () => _save(shop),
              child: Text(provider.isSaving ? 'Saving…' : 'Save'),
            ),
        ],
      ),
      body: provider.isLoading && shop == null
          ? const _ShopProfileSkeleton()
          : shop == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Text(
                      provider.error ?? 'Shop not found',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildForm(shop),
      ),
    );
  }

  Widget _buildForm(Shop shop) {
    _hydrate(shop);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.huge),
        children: [
          _BannerEditor(
            url: _bannerUrl,
            isUploading: _uploadingBanner,
            onPick: () => _pickImage(isLogo: false),
            onRemove: _bannerUrl == null
                ? null
                : () => setState(() => _bannerUrl = null),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg)
                .copyWith(top: AppSizes.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LogoEditor(
                  url: _logoUrl,
                  isUploading: _uploadingLogo,
                  onPick: () => _pickImage(isLogo: true),
                  onRemove: _logoUrl == null
                      ? null
                      : () => setState(() => _logoUrl = null),
                ),
                const SizedBox(width: AppSizes.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            shop.isPublished
                                ? Icons.public
                                : Icons.public_off_outlined,
                            size: AppSizes.iconSm,
                            color: shop.isPublished
                                ? AppColors.brand
                                : AppColors.muted,
                          ),
                          const SizedBox(width: AppSizes.xs),
                          Text(
                            shop.isPublished
                                ? 'Live on marketplace · /${shop.slug}'
                                : 'Not published',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: shop.isPublished
                                      ? AppColors.brand
                                      : AppColors.muted,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Shop name',
                    helperText:
                        'Shown on the marketplace. Renaming updates the public URL slug.',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.length < 2) return 'Min 2 characters';
                    if (value.length > 80) return 'Max 80 characters';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSizes.lg),
                TextFormField(
                  controller: _tagline,
                  decoration: const InputDecoration(
                    labelText: 'Tagline (optional)',
                    helperText: 'One-liner shown below your shop name.',
                  ),
                  maxLength: 140,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSizes.lg),
                _SectionHeader(
                  title: 'Location',
                  subtitle:
                      'Optional. Surfaces a "Based in …" line on your '
                      'public shop page.',
                ),
                const SizedBox(height: AppSizes.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationCity,
                        decoration: const InputDecoration(
                          labelText: 'City',
                        ),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: TextFormField(
                        controller: _locationState,
                        decoration: const InputDecoration(
                          labelText: 'State',
                        ),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xl),
                _SectionHeader(
                  title: 'Policies',
                  subtitle:
                      'Customers see these on your shop page and as a '
                      '"Policies" pill on every PDP. Plain text. Up to '
                      '4 KB each.',
                ),
                const SizedBox(height: AppSizes.md),
                TextFormField(
                  controller: _returnPolicy,
                  decoration: const InputDecoration(
                    labelText: 'Return policy',
                    hintText:
                        'e.g. 7-day return on unused items. Original '
                        'packaging required.',
                  ),
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 4096,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSizes.md),
                TextFormField(
                  controller: _shippingPolicy,
                  decoration: const InputDecoration(
                    labelText: 'Shipping policy',
                    hintText:
                        'e.g. Ships within 24 hours from Bengaluru. '
                        '3–5 business days delivery.',
                  ),
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 4096,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSizes.md),
                TextFormField(
                  controller: _refundPolicy,
                  decoration: const InputDecoration(
                    labelText: 'Refund policy',
                    hintText:
                        'e.g. Refunds processed within 5 business days '
                        'to the original payment method.',
                  ),
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 4096,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSizes.xl),
                _SectionHeader(
                  title: 'Returns & cancellation',
                  subtitle:
                      'Whether customers can return orders, how refunds '
                      'are issued, and how late an order can be '
                      'cancelled.',
                ),
                const SizedBox(height: AppSizes.sm),
                SwitchListTile.adaptive(
                  value: _returnsEnabled,
                  onChanged: (v) => setState(() => _returnsEnabled = v),
                  title: const Text('Accept returns'),
                  subtitle: const Text(
                    "When off, customers can't request post-delivery "
                    'returns.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_returnsEnabled) ...[
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _returnWindowDays,
                    decoration: const InputDecoration(
                      labelText: 'Return window (days)',
                      helperText: '0 means no time limit.',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (!_returnsEnabled) return null;
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0 || n > 365) {
                        return 'Enter a whole number between 0 and 365';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSizes.md),
                  DropdownButtonFormField<String>(
                    initialValue: _refundMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Refund method',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'WALLET',
                        child: Text('Store wallet credit'),
                      ),
                      DropdownMenuItem(
                        value: 'ORIGINAL',
                        child: Text('Original payment method'),
                      ),
                      DropdownMenuItem(
                        value: 'REPLACEMENT',
                        child: Text('Replacement only'),
                      ),
                    ],
                    onChanged: (v) => setState(
                      () => _refundMode = v ?? _refundMode,
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _returnPolicyNote,
                    decoration: const InputDecoration(
                      labelText: 'Return policy note (optional)',
                      hintText:
                          'e.g. Items must be unused and in original '
                          'packaging. Buyer pays return shipping.',
                    ),
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 2048,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: AppSizes.md),
                DropdownButtonFormField<String>(
                  initialValue: _cancellationPolicy,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Customers can cancel',
                    helperText:
                        'After this stage they must use a post-delivery '
                        'return instead.',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'UNTIL_CONFIRMED',
                      child: Text('Until I confirm the order'),
                    ),
                    DropdownMenuItem(
                      value: 'UNTIL_PACKED',
                      child: Text('Until packed'),
                    ),
                    DropdownMenuItem(
                      value: 'UNTIL_SHIPPED',
                      child: Text('Until shipped (recommended)'),
                    ),
                    DropdownMenuItem(
                      value: 'UNTIL_DELIVERED',
                      child: Text('Until delivered'),
                    ),
                  ],
                  onChanged: (v) => setState(
                    () => _cancellationPolicy = v ?? _cancellationPolicy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          _PublishCard(shop: shop, onToggle: () => _togglePublish(shop)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton shown while provider.isLoading && shop == null
// ---------------------------------------------------------------------------

class _ShopProfileSkeleton extends StatelessWidget {
  const _ShopProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: const [
        _BannerSkeleton(),
        _HeaderRowSkeleton(),
        SizedBox(height: AppSizes.xl),
        _FormFieldsSkeleton(),
        SizedBox(height: AppSizes.lg),
        _PublishCardSkeleton(),
      ],
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.5,
      child: AppShimmerBox(
        width: double.infinity,
        height: double.infinity,
        radius: 0,
      ),
    );
  }
}

class _HeaderRowSkeleton extends StatelessWidget {
  const _HeaderRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg)
          .copyWith(top: AppSizes.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo placeholder
          AppShimmerBox(width: 72, height: 72, radius: AppSizes.radiusLg),
          const SizedBox(width: AppSizes.lg),
          // Title + metadata lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppShimmerLine(widthFactor: 0.55, height: 20),
                const SizedBox(height: AppSizes.sm),
                const AppShimmerLine(widthFactor: 0.75, height: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFieldsSkeleton extends StatelessWidget {
  const _FormFieldsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop name field
          const AppShimmerLine(widthFactor: 1.0, height: 48),
          const SizedBox(height: AppSizes.lg),
          // Tagline field
          const AppShimmerLine(widthFactor: 1.0, height: 48),
          const SizedBox(height: AppSizes.lg),
          // Location section header
          const AppShimmerLine(widthFactor: 0.3, height: 16),
          const SizedBox(height: AppSizes.md),
          // City + State row
          Row(
            children: [
              Expanded(
                child: AppShimmerLine(widthFactor: 1.0, height: 48),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: AppShimmerLine(widthFactor: 1.0, height: 48),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xl),
          // Policies section header
          const AppShimmerLine(widthFactor: 0.25, height: 16),
          const SizedBox(height: AppSizes.md),
          // Return policy (multi-line)
          AppShimmerBox(
            width: double.infinity,
            height: 88,
            radius: AppSizes.radiusMd,
          ),
          const SizedBox(height: AppSizes.md),
          // Shipping policy (multi-line)
          AppShimmerBox(
            width: double.infinity,
            height: 88,
            radius: AppSizes.radiusMd,
          ),
          const SizedBox(height: AppSizes.md),
          // Refund policy (multi-line)
          AppShimmerBox(
            width: double.infinity,
            height: 88,
            radius: AppSizes.radiusMd,
          ),
        ],
      ),
    );
  }
}

class _PublishCardSkeleton extends StatelessWidget {
  const _PublishCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusLg,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Row(
          children: [
            AppShimmerBox(width: 24, height: 24, radius: AppSizes.radiusSm),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppShimmerLine(widthFactor: 0.5, height: 16),
                  const SizedBox(height: AppSizes.xs),
                  const AppShimmerLine(widthFactor: 0.9, height: 12),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            AppShimmerBox(width: 48, height: 28, radius: AppSizes.radiusFull),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

class _BannerEditor extends StatelessWidget {
  const _BannerEditor({
    required this.url,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
  });
  final String? url;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: AspectRatio(
        aspectRatio: 2.5,
        child: Container(
          color: AppColors.heroPanel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null)
                Image.network(
                  resolveImageUrl(url!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _BannerPlaceholder(),
                )
              else
                const _BannerPlaceholder(),
              if (isUploading)
                Container(
                  color: AppColors.black.withValues(alpha: 0.3),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: AppColors.white),
                ),
              Positioned(
                right: AppSizes.md,
                bottom: AppSizes.md,
                child: Row(
                  children: [
                    if (onRemove != null) ...[
                      _ImageActionChip(
                        icon: Icons.delete_outline,
                        label: 'Remove',
                        onTap: onRemove!,
                      ),
                      const SizedBox(width: AppSizes.sm),
                    ],
                    _ImageActionChip(
                      icon: Icons.camera_alt_outlined,
                      label: url == null ? 'Add banner' : 'Replace',
                      onTap: onPick,
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
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              size: AppSizes.iconXl,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Add a banner',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ],
        ),
      );
}

class _LogoEditor extends StatelessWidget {
  const _LogoEditor({
    required this.url,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
  });
  final String? url;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Stack(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(
                AppSizes.radiusLg,
                side: const BorderSide(color: AppColors.hairline),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: url != null
                ? Image.network(
                    resolveImageUrl(url!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.storefront_outlined,
                      color: AppColors.muted,
                    ),
                  )
                : const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppColors.muted,
                  ),
          ),
          if (isUploading)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: SizedBox(
                    width: AppSizes.iconLg,
                    height: AppSizes.iconLg,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: AppSizes.iconSm,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageActionChip extends StatelessWidget {
  const _ImageActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppSizes.iconSm, color: AppColors.black),
              const SizedBox(width: AppSizes.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishCard extends StatelessWidget {
  const _PublishCard({required this.shop, required this.onToggle});
  final Shop shop;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = shop.isPublished ? AppColors.brand : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusLg,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Row(
          children: [
            Icon(
              shop.isPublished ? Icons.public : Icons.public_off_outlined,
              color: color,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.isPublished
                        ? 'Live on marketplace'
                        : 'Not published yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shop.isPublished
                        ? 'Customers can find your shop and your published products.'
                        : 'Toggle on once your logo, banner and at least one product are ready.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: shop.isPublished,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}
