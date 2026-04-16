import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shopxy/features/products/domain/entities/product_draft.dart';

class ProductOcrParser {
  const ProductOcrParser._();

  static ProductDraft fromText(RecognizedText text) {
    final lines = text.blocks
        .expand((block) => block.lines)
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    String? name;
    String? sku;
    String? barcode;
    String? hsnCode;
    double? mrp;
    double? sellingPrice;
    double? purchasePrice;
    double? taxPercent;

    for (final line in lines) {
      final lower = line.toLowerCase();

      sku ??= _extractLabeledValue(
        line,
        RegExp(r'(sku|item\s*code|item\s*no|code)[:#\s-]*([A-Za-z0-9-]+)', caseSensitive: false),
      );
      hsnCode ??= _extractLabeledValue(
        line,
        RegExp(r'(hsn|hsn\s*code)[:#\s-]*([A-Za-z0-9-]+)', caseSensitive: false),
      );
      barcode ??= _extractLabeledValue(
        line,
        RegExp(r'(barcode|bar\s*code|ean|upc)[:#\s-]*([0-9-]{8,})', caseSensitive: false),
      );

      if (lower.contains('mrp')) {
        mrp ??= _extractNumber(line);
      } else if (lower.contains('selling') || lower.contains('sale')) {
        sellingPrice ??= _extractNumber(line);
      } else if (lower.contains('purchase') || lower.contains('cost') || lower.contains('buy')) {
        purchasePrice ??= _extractNumber(line);
      }

      if (lower.contains('gst') || lower.contains('tax')) {
        taxPercent ??= _extractNumber(line);
      }
    }

    barcode ??= _findBarcode(lines);
    name ??= _findName(lines);

    return ProductDraft(
      name: name,
      sku: sku ?? barcode,
      barcode: barcode,
      hsnCode: hsnCode,
      mrp: mrp,
      sellingPrice: sellingPrice,
      purchasePrice: purchasePrice,
      taxPercent: taxPercent,
    );
  }

  static String? _extractLabeledValue(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match == null) return null;
    return match.group(2)?.replaceAll(RegExp(r'\s+'), '').trim();
  }

  static double? _extractNumber(String text) {
    final match = RegExp(r'(\d+(?:[\.,]\d+)?)').firstMatch(text);
    if (match == null) return null;
    final raw = match.group(1)?.replaceAll(',', '.');
    return raw == null ? null : double.tryParse(raw);
  }

  static String? _findBarcode(List<String> lines) {
    final digitPattern = RegExp(r'\b\d{8,14}\b');
    String? best;
    for (final line in lines) {
      final match = digitPattern.firstMatch(line.replaceAll(' ', ''));
      if (match == null) continue;
      final candidate = match.group(0);
      if (candidate == null) continue;
      if (best == null || candidate.length > best.length) {
        best = candidate;
      }
    }
    return best;
  }

  static String? _findName(List<String> lines) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('mrp') ||
          lower.contains('price') ||
          lower.contains('gst') ||
          lower.contains('tax') ||
          lower.contains('sku') ||
          lower.contains('hsn') ||
          lower.contains('barcode')) {
        continue;
      }
      final letters = RegExp(r'[a-zA-Z]').allMatches(line).length;
      final digits = RegExp(r'\d').allMatches(line).length;
      if (letters >= 3 && digits == 0) {
        return line.trim();
      }
    }
    return null;
  }
}
