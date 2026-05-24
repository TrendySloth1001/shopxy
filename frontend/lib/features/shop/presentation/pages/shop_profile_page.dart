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
    _logoUrl = shop.logoUrl;
    _bannerUrl = shop.bannerUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
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
    setState(() {
      if (isLogo) {
        _uploadingLogo = true;
      } else {
        _uploadingBanner = true;
      }
    });
    final url = await context
        .read<ShopProvider>()
        .uploadImage(File(picked.path));
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
        const SnackBar(content: Text('Image upload failed')),
      );
    }
  }

  bool _isDirty(Shop shop) {
    return _name.text.trim() != shop.name ||
        (_tagline.text.trim().isEmpty ? null : _tagline.text.trim()) !=
            shop.tagline ||
        _logoUrl != shop.logoUrl ||
        _bannerUrl != shop.bannerUrl;
  }

  Future<void> _save(Shop current) async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ShopProvider>();
    final newName = _name.text.trim();
    final newTagline = _tagline.text.trim().isEmpty ? null : _tagline.text.trim();
    final ok = await provider.save(
      name: newName == current.name ? null : newName,
      tagline: newTagline == current.tagline ? const Object() : newTagline,
      logoUrl: _logoUrl == current.logoUrl ? const Object() : _logoUrl,
      bannerUrl: _bannerUrl == current.bannerUrl ? const Object() : _bannerUrl,
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShopProvider>();
    final shop = provider.shop;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('My Shop'),
        actions: [
          if (shop != null && _isDirty(shop))
            TextButton(
              onPressed: provider.isSaving ? null : () => _save(shop),
              child: Text(provider.isSaving ? 'Saving…' : 'Save'),
            ),
        ],
      ),
      body: provider.isLoading && shop == null
          ? const Center(child: CircularProgressIndicator())
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
                            size: 14,
                            color: shop.isPublished
                                ? AppColors.brand
                                : AppColors.muted,
                          ),
                          const SizedBox(width: 4),
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
                  color: Colors.black.withValues(alpha: 0.3),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: Colors.white),
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
              size: 32,
              color: AppColors.muted,
            ),
            const SizedBox(height: 4),
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
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
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
                    size: 14,
                    color: Colors.white,
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
      color: Colors.white,
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
              Icon(icon, size: 14, color: AppColors.black),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 11,
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
