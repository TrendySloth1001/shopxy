import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/products/domain/entities/product_draft.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/add_edit_product_page.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

enum _MissingProductAction { add, retry }

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final provider = context.read<ProductsProvider>();
    setState(() => _isProcessing = true);
    await _controller.stop();

    final code = barcode.rawValue!;
    final Product? product = await provider.lookupByCode(code);

    if (!mounted) return;

    if (product != null) {
      Navigator.pop(context, product);
    } else {
      final action = await _showMissingProductSheet(code);
      if (!mounted) return;

      if (action == _MissingProductAction.add) {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditProductPage(
              draft: ProductDraft(sku: code, barcode: code),
            ),
          ),
        );

        if (!mounted) return;

        if (created == true) {
          final createdProduct = await provider.lookupByCode(code);
          if (!mounted) return;
          if (createdProduct != null) {
            Navigator.pop(context, createdProduct);
            return;
          }
        }
      }

      setState(() => _isProcessing = false);
      await _controller.start();
    }
  }

  Future<_MissingProductAction?> _showMissingProductSheet(String code) {
    return showModalBottomSheet<_MissingProductAction>(
      context: context,
      isScrollControlled: true,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: AppSizes.xl,
            right: AppSizes.xl,
            top: AppSizes.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: ShapeDecoration(
                    color: theme.colorScheme.outlineVariant,
                    shape: AppShapes.squircle(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Icon(
                Icons.qr_code_rounded,
                size: AppSizes.iconHuge,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                AppStrings.productNotFoundTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                AppStrings.productNotFoundHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: AppSizes.sm,
                  ),
                  decoration: ShapeDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: Text(
                    code,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.xl),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, _MissingProductAction.add),
                icon: const Icon(Icons.add_rounded),
                label: const Text(AppStrings.addProduct),
              ),
              const SizedBox(height: AppSizes.sm),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(ctx, _MissingProductAction.retry),
                child: const Text(AppStrings.scanAgain),
              ),
              const SizedBox(height: AppSizes.xl),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.scanQr),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Scan overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: ShapeDecoration(
                shape: AppShapes.squircle(
                  AppSizes.radiusLg,
                  side: BorderSide(color: theme.colorScheme.primary, width: 3),
                ),
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: AppSizes.huge,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xl,
                  vertical: AppSizes.md,
                ),
                decoration: ShapeDecoration(
                  color: Colors.black54,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
                child: Text(
                  _isProcessing ? AppStrings.loading : AppStrings.scanHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
