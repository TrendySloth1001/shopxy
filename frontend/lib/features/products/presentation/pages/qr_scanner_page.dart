import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

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

    setState(() => _isProcessing = true);

    final code = barcode.rawValue!;
    final provider = context.read<ProductsProvider>();
    final Product? product = await provider.lookupByCode(code);

    if (!mounted) return;

    if (product != null) {
      Navigator.pop(context, product);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.productNotFound}: $code'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
      setState(() => _isProcessing = false);
    }
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
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
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
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  _isProcessing ? AppStrings.loading : 'Point camera at QR or barcode',
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
