import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Phase C — renders the merchant-authored A+ content blocks beneath
/// the highlights in the PDP Details tab. Dispatches on `block.kind`
/// to a per-kind widget; an unknown kind collapses to a tiny "Unsupported
/// content" stub so a server-side schema bump never crashes a shipped
/// client.
class PdpContentBlocks extends StatelessWidget {
  const PdpContentBlocks({super.key, required this.blocks});
  final List<ContentBlock> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Description',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.black),
          ),
          const SizedBox(height: AppSizes.sm),
          for (final b in blocks) ...[
            _renderBlock(b),
            const SizedBox(height: AppSizes.md),
          ],
        ],
      ),
    );
  }

  Widget _renderBlock(ContentBlock b) {
    switch (b.kind) {
      case 'HERO':
        return _HeroBlock(data: b.data);
      case 'FEATURE':
        return _FeatureBlock(data: b.data);
      case 'GALLERY':
        return _GalleryBlock(data: b.data);
      case 'COMPARISON':
        return _ComparisonBlock(data: b.data);
      case 'TEXT':
        return _TextBlock(data: b.data);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final url = (data['imageUrl'] as String?) ?? '';
    final headline = (data['headline'] as String?) ?? '';
    final subtext = data['subtext'] as String?;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isNotEmpty)
              NetworkImageBox(url: resolveImageUrl(url), fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  if (subtext != null && subtext.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtext,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
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

class _FeatureBlock extends StatelessWidget {
  const _FeatureBlock({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final url = (data['imageUrl'] as String?) ?? '';
    final title = (data['title'] as String?) ?? '';
    final body = (data['body'] as String?) ?? '';
    final side = (data['side'] as String?) ?? 'LEFT';
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: AspectRatio(
        aspectRatio: 1,
        child: url.isEmpty
            ? Container(color: AppColors.heroPanel)
            : NetworkImageBox(url: resolveImageUrl(url), fit: BoxFit.cover),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14, color: AppColors.black),
        ),
        if (body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              body,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: side == 'LEFT'
          ? [
              SizedBox(width: 110, child: image),
              const SizedBox(width: AppSizes.md),
              Expanded(child: text),
            ]
          : [
              Expanded(child: text),
              const SizedBox(width: AppSizes.md),
              SizedBox(width: 110, child: image),
            ],
    );
  }
}

class _GalleryBlock extends StatelessWidget {
  const _GalleryBlock({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final images = ((data['images'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (_, i) {
          final img = images[i];
          final url = (img['url'] as String?) ?? '';
          final caption = img['caption'] as String?;
          return SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    child: url.isEmpty
                        ? Container(color: AppColors.heroPanel)
                        : NetworkImageBox(
                            url: resolveImageUrl(url), fit: BoxFit.cover),
                  ),
                ),
                if (caption != null && caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ComparisonBlock extends StatelessWidget {
  const _ComparisonBlock({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final columns = ((data['columns'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final rows = ((data['rows'] as List?) ?? const []).cast<String>();
    if (columns.length < 2 || rows.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.hairline),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.black),
          dataTextStyle: const TextStyle(
              fontSize: 12, color: AppColors.black),
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 36,
          columns: [
            const DataColumn(label: Text('')),
            for (final c in columns)
              DataColumn(label: Text((c['label'] as String?) ?? '')),
          ],
          rows: [
            for (var r = 0; r < rows.length; r++)
              DataRow(cells: [
                DataCell(Text(rows[r],
                    style: const TextStyle(color: AppColors.muted))),
                for (final c in columns)
                  DataCell(Text(((c['values'] as List?) ?? const [])
                          .cast<String>()
                          .elementAtOrNull(r) ??
                      '—')),
              ]),
          ],
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final md = (data['markdown'] as String?) ?? '';
    if (md.isEmpty) return const SizedBox.shrink();
    return Text(
      md,
      style: const TextStyle(
        color: AppColors.black,
        fontSize: 13,
        height: 1.5,
      ),
    );
  }
}
