import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves quotation PDF bytes to a temp file and opens the platform share /
/// save / print sheet. Mirrors the orders feature's `shareInvoicePdf` — going
/// through a real file (not `XFile.fromData`) is required on iOS.
Future<void> shareQuotationPdf({
  required BuildContext context,
  required String quotationNo,
  required Uint8List bytes,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.attached
      ? box.localToGlobal(Offset.zero) & box.size
      : null;

  final dir = await getTemporaryDirectory();
  final safeName = quotationNo.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final file = File('${dir.path}/quotation-$safeName.pdf');
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Quotation $quotationNo',
      sharePositionOrigin: origin,
    ),
  );
}
