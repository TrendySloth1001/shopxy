import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves the PDF bytes to a temp file the platform share sheet can
/// open / save / print. Going through a real file (not `XFile.fromData`)
/// is required on iOS — UIActivityViewController otherwise refuses
/// to attach the document.
Future<void> shareInvoicePdf({
  required BuildContext context,
  required String invoiceNo,
  required Uint8List bytes,
}) async {
  // Capture the iPad popover anchor before the first await — accessing
  // `context.findRenderObject()` after the async gap is unsafe.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.attached
      ? box.localToGlobal(Offset.zero) & box.size
      : null;

  final dir = await getTemporaryDirectory();
  final safeName = invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final file = File('${dir.path}/invoice-$safeName.pdf');
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Invoice $invoiceNo',
      sharePositionOrigin: origin,
    ),
  );
}
