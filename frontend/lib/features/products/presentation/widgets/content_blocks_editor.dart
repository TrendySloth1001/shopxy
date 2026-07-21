import 'package:flutter/material.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

/// Phase C — A+ content blocks editor used inside the add/edit product
/// page. Each block is one of HERO / FEATURE / COMPARISON / GALLERY /
/// TEXT (mirrors the backend `contentBlockSchema`). Hard cap 8 blocks
/// enforced client + server.
///
/// The editor reads/writes [blocks] in place: the parent owns the list,
/// the widget mutates it directly. Same pattern used by the specs and
/// offers editors in the add/edit product page.
///
/// [onPickImage] uploads an image (gallery/camera handled by the page)
/// and returns its stored URL — every image field offers it so the
/// merchant never has to hand-paste a link.
class ContentBlocksEditor extends StatefulWidget {
  const ContentBlocksEditor({
    super.key,
    required this.blocks,
    required this.onChange,
    required this.onPickImage,
  });
  final List<ContentBlock> blocks;
  final VoidCallback onChange;
  final Future<String?> Function() onPickImage;

  @override
  State<ContentBlocksEditor> createState() => _ContentBlocksEditorState();
}

class _ContentBlocksEditorState extends State<ContentBlocksEditor> {
  static const _maxBlocks = 8;

  // Friendly metadata for the "add a block" menu — plain-language label
  // + a one-liner so the merchant knows what each block does without
  // having to guess from an acronym. Labels/hints resolved via l10n at
  // render time; only the kind + icon are static.
  static const _kinds = <(String, AppIconData)>[
    ('HERO', AppIcons.wallpaperRounded),
    ('FEATURE', AppIcons.viewSidebarRounded),
    ('COMPARISON', AppIcons.tableChartRounded),
    ('GALLERY', AppIcons.collectionsRounded),
    ('TEXT', AppIcons.notesRounded),
  ];

  (String, String) _kindLabelHint(AppLocalizations l10n, String kind) =>
      switch (kind) {
        'HERO' => (l10n.productsBlockHeroLabel, l10n.productsBlockHeroHint),
        'FEATURE' => (
          l10n.productsBlockFeatureLabel,
          l10n.productsBlockFeatureHint,
        ),
        'COMPARISON' => (
          l10n.productsBlockComparisonLabel,
          l10n.productsBlockComparisonHint,
        ),
        'GALLERY' => (
          l10n.productsBlockGalleryLabel,
          l10n.productsBlockGalleryHint,
        ),
        'TEXT' ||
        _ => (l10n.productsBlockTextLabel, l10n.productsBlockTextHint),
      };

  void _add(String kind) {
    if (widget.blocks.length >= _maxBlocks) return;
    setState(() {
      widget.blocks.add(ContentBlock(kind: kind, data: _defaultPayload(kind)));
    });
    widget.onChange();
  }

  void _remove(int i) {
    setState(() => widget.blocks.removeAt(i));
    widget.onChange();
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= widget.blocks.length) return;
    setState(() {
      final tmp = widget.blocks[i];
      widget.blocks[i] = widget.blocks[j];
      widget.blocks[j] = tmp;
    });
    widget.onChange();
  }

  void _update(int i, Map<String, dynamic> next) {
    setState(() {
      widget.blocks[i] = widget.blocks[i].copyWith(data: next);
    });
    widget.onChange();
  }

  Map<String, dynamic> _defaultPayload(String kind) => switch (kind) {
    'HERO' => {'imageUrl': '', 'headline': ''},
    'FEATURE' => {'imageUrl': '', 'side': 'LEFT', 'title': '', 'body': ''},
    'COMPARISON' => {
      'columns': [
        {
          'label': 'This product',
          'values': <String>[''],
        },
        {
          'label': 'Others',
          'values': <String>[''],
        },
      ],
      'rows': <String>[''],
    },
    'GALLERY' => {
      'images': [
        {'url': ''},
      ],
    },
    'TEXT' || _ => {'markdown': ''},
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: Text(
              l10n.productsBlocksEmptyHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ),
        for (var i = 0; i < widget.blocks.length; i++)
          _BlockCard(
            block: widget.blocks[i],
            index: i,
            total: widget.blocks.length,
            onUpdate: (next) => _update(i, next),
            onRemove: () => _remove(i),
            onUp: () => _move(i, -1),
            onDown: () => _move(i, 1),
            onPickImage: widget.onPickImage,
          ),
        if (widget.blocks.length < _maxBlocks) ...[
          const SizedBox(height: AppSizes.sm),
          for (final (kind, icon) in _kinds)
            Builder(
              builder: (_) {
                final (label, hint) = _kindLabelHint(l10n, kind);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.sm),
                  child: _AddBlockTile(
                    icon: icon,
                    label: label,
                    hint: hint,
                    onTap: () => _add(kind),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }
}

/// A tappable "add this kind of block" row — plain-language label + a
/// hint so the merchant picks the right block on the first try.
class _AddBlockTile extends StatelessWidget {
  const _AddBlockTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });
  final AppIconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(color: AppColors.hairline, width: 1),
          ),
        ),
        child: Row(
          children: [
            AppIcon(icon, size: AppSizes.iconMd, color: AppColors.muted),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium?.bold),
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            AppIcon(AppIcons.addRounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.block,
    required this.index,
    required this.total,
    required this.onUpdate,
    required this.onRemove,
    required this.onUp,
    required this.onDown,
    required this.onPickImage,
  });
  final ContentBlock block;
  final int index;
  final int total;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final VoidCallback onRemove;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final Future<String?> Function() onPickImage;

  String _blockTitle(AppLocalizations l10n, String kind) => switch (kind) {
    'HERO' => l10n.productsBlockHeroLabel,
    'FEATURE' => l10n.productsBlockFeature,
    'COMPARISON' => l10n.productsBlockComparisonLabel,
    'GALLERY' => l10n.productsBlockGallery,
    'TEXT' => l10n.productsBlockText,
    _ => kind,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: 3,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                child: Text(
                  _blockTitle(l10n, block.kind),
                  style: theme.textTheme.labelSmall?.extraBold,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                l10n.productsBlockPosition('${index + 1}', '$total'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.productsMoveUp,
                visualDensity: VisualDensity.compact,
                onPressed: index == 0 ? null : onUp,
                icon: const AppIcon(AppIcons.keyboardArrowUpRounded),
              ),
              IconButton(
                tooltip: l10n.productsMoveDown,
                visualDensity: VisualDensity.compact,
                onPressed: index == total - 1 ? null : onDown,
                icon: const AppIcon(AppIcons.keyboardArrowDownRounded),
              ),
              IconButton(
                tooltip: l10n.productsRemove,
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const AppIcon(AppIcons.deleteOutline),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          _BlockForm(
            block: block,
            onUpdate: onUpdate,
            onPickImage: onPickImage,
          ),
        ],
      ),
    );
  }
}

class _BlockForm extends StatelessWidget {
  const _BlockForm({
    required this.block,
    required this.onUpdate,
    required this.onPickImage,
  });
  final ContentBlock block;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final Future<String?> Function() onPickImage;

  Map<String, dynamic> _patch(Map<String, dynamic> patch) => {
    ...block.data,
    ...patch,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (block.kind) {
      case 'HERO':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImageField(
              label: l10n.productsBannerImage,
              value: block.data['imageUrl'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'imageUrl': v})),
              onPickImage: onPickImage,
            ),
            const SizedBox(height: 10),
            _TextLine(
              label: l10n.productsHeadline,
              value: block.data['headline'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'headline': v})),
              maxLength: 120,
            ),
            const SizedBox(height: AppSizes.sm),
            _TextLine(
              label: l10n.productsSubtext,
              value: block.data['subtext'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'subtext': v})),
              maxLength: 240,
            ),
          ],
        );
      case 'FEATURE':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImageField(
              label: l10n.productsFeatureImage,
              value: block.data['imageUrl'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'imageUrl': v})),
              onPickImage: onPickImage,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(l10n.productsImageOnThe),
                const SizedBox(width: AppSizes.sm),
                DropdownButton<String>(
                  value: (block.data['side'] as String?) ?? 'LEFT',
                  items: [
                    DropdownMenuItem(
                      value: 'LEFT',
                      child: Text(l10n.productsSideLeft),
                    ),
                    DropdownMenuItem(
                      value: 'RIGHT',
                      child: Text(l10n.productsSideRight),
                    ),
                  ],
                  onChanged: (v) =>
                      v == null ? null : onUpdate(_patch({'side': v})),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            _TextLine(
              label: l10n.productsFieldTitle,
              value: block.data['title'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'title': v})),
              maxLength: 120,
            ),
            const SizedBox(height: AppSizes.sm),
            _TextArea(
              label: l10n.productsDescription,
              value: block.data['body'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'body': v})),
              maxLength: 500,
            ),
          ],
        );
      case 'GALLERY':
        final imgs = ((block.data['images'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < imgs.length; i++) ...[
              _ImageField(
                label: l10n.productsImageN('${i + 1}'),
                value: imgs[i]['url'] as String? ?? '',
                onChanged: (v) {
                  imgs[i] = {...imgs[i], 'url': v};
                  onUpdate(_patch({'images': imgs}));
                },
                onPickImage: onPickImage,
                onRemove: () {
                  imgs.removeAt(i);
                  onUpdate(_patch({'images': imgs}));
                },
              ),
              _TextLine(
                label: l10n.productsCaption,
                value: imgs[i]['caption'] as String? ?? '',
                onChanged: (v) {
                  imgs[i] = {...imgs[i], 'caption': v};
                  onUpdate(_patch({'images': imgs}));
                },
                maxLength: 140,
              ),
              const SizedBox(height: AppSizes.md),
            ],
            if (imgs.length < 6)
              OutlinedButton.icon(
                icon: const AppIcon(AppIcons.add, size: 16),
                label: Text(l10n.productsAddImageAction),
                onPressed: () {
                  imgs.add({'url': ''});
                  onUpdate(_patch({'images': imgs}));
                },
              ),
          ],
        );
      case 'COMPARISON':
        return _ComparisonEditor(
          data: block.data,
          onChanged: (next) => onUpdate(next),
        );
      case 'TEXT':
      default:
        return _TextArea(
          label: l10n.productsBlockText,
          value: block.data['markdown'] as String? ?? '',
          onChanged: (v) => onUpdate(_patch({'markdown': v})),
          maxLength: 2000,
        );
    }
  }
}

/// Structured comparison-table editor (replaces the old raw-JSON
/// textarea). The merchant names the columns they're comparing, then
/// adds feature rows and fills one cell per column. The widget keeps
/// every column's `values` array the same length as `rows` so the saved
/// payload always matches the backend's `contentBlockSchema`.
class _ComparisonEditor extends StatefulWidget {
  const _ComparisonEditor({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<_ComparisonEditor> createState() => _ComparisonEditorState();
}

class _ComparisonEditorState extends State<_ComparisonEditor> {
  late List<Map<String, dynamic>> _columns;
  late List<String> _rows;

  static const _maxColumns = 4;
  static const _minColumns = 2;
  static const _maxRows = 10;

  @override
  void initState() {
    super.initState();
    _columns = (((widget.data['columns'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (m) => <String, dynamic>{
            'label': (m['label'] as String?) ?? '',
            'values': ((m['values'] as List?) ?? const [])
                .map((e) => e?.toString() ?? '')
                .toList(),
          },
        )
        .toList());
    _rows = ((widget.data['rows'] as List?) ?? const [])
        .map((e) => e?.toString() ?? '')
        .toList();
    // Seed sane defaults if a fresh/empty block landed here.
    while (_columns.length < _minColumns) {
      _columns.add(<String, dynamic>{'label': '', 'values': <String>[]});
    }
    if (_rows.isEmpty) _rows = [''];
    _normalize();
  }

  /// Keep every column's value list aligned 1:1 with [_rows].
  void _normalize() {
    for (final c in _columns) {
      final vals = (c['values'] as List).cast<String>();
      while (vals.length < _rows.length) {
        vals.add('');
      }
      while (vals.length > _rows.length) {
        vals.removeLast();
      }
      c['values'] = vals;
    }
  }

  void _emit() {
    widget.onChanged(<String, dynamic>{
      'columns': _columns
          .map(
            (c) => <String, dynamic>{
              'label': c['label'],
              'values': c['values'],
            },
          )
          .toList(),
      'rows': _rows,
    });
  }

  void _mutate(VoidCallback fn) {
    setState(() {
      fn();
      _normalize();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.productsComparisonIntro,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSizes.md),
        Text(
          l10n.productsColumns,
          style: theme.textTheme.labelMedium?.extraBold,
        ),
        const SizedBox(height: AppSizes.sm),
        for (var c = 0; c < _columns.length; c++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _columns[c]['label'] as String,
                    onChanged: (v) => _mutate(() => _columns[c]['label'] = v),
                    decoration: InputDecoration(
                      labelText: l10n.productsColumnNName('${c + 1}'),
                      hintText: c == 0
                          ? l10n.productsThisProductHint
                          : l10n.productsOtherCompetitorHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (_columns.length > _minColumns)
                  IconButton(
                    icon: const AppIcon(AppIcons.close, size: 18),
                    tooltip: l10n.productsRemoveColumn,
                    onPressed: () => _mutate(() => _columns.removeAt(c)),
                  ),
              ],
            ),
          ),
        if (_columns.length < _maxColumns)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const AppIcon(AppIcons.add, size: 16),
              label: Text(l10n.productsAddColumn),
              onPressed: () => _mutate(
                () => _columns.add(<String, dynamic>{
                  'label': '',
                  'values': <String>[],
                }),
              ),
            ),
          ),
        const SizedBox(height: AppSizes.md),
        Text(l10n.productsRows, style: theme.textTheme.labelMedium?.extraBold),
        const SizedBox(height: AppSizes.sm),
        for (var r = 0; r < _rows.length; r++)
          Container(
            margin: const EdgeInsets.only(bottom: AppSizes.sm),
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: ShapeDecoration(
              color: AppColors.surfaceTint,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _rows[r],
                        onChanged: (v) => _mutate(() => _rows[r] = v),
                        decoration: InputDecoration(
                          labelText: l10n.productsFeature,
                          hintText: l10n.productsFeatureHint,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_rows.length > 1)
                      IconButton(
                        icon: const AppIcon(AppIcons.deleteOutline, size: 20),
                        tooltip: l10n.productsRemoveRow,
                        onPressed: () => _mutate(() {
                          _rows.removeAt(r);
                          for (final c in _columns) {
                            (c['values'] as List).removeAt(r);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var c = 0; c < _columns.length; c++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TextFormField(
                      initialValue:
                          (_columns[c]['values'] as List)[r] as String,
                      onChanged: (v) =>
                          _mutate(() => (_columns[c]['values'] as List)[r] = v),
                      decoration: InputDecoration(
                        labelText:
                            (_columns[c]['label'] as String).trim().isEmpty
                            ? l10n.productsColumnN('${c + 1}')
                            : _columns[c]['label'] as String,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (_rows.length < _maxRows)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const AppIcon(AppIcons.add, size: 16),
              label: Text(l10n.productsAddRow),
              onPressed: () => _mutate(() => _rows.add('')),
            ),
          ),
      ],
    );
  }
}

/// Image field with an inline thumbnail, an Upload button (reuses the
/// page's picker via [onPickImage]) and a "paste a link" fallback so a
/// merchant never has to know what a URL is to add a picture.
class _ImageField extends StatefulWidget {
  const _ImageField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onPickImage,
    this.onRemove,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final Future<String?> Function() onPickImage;
  final VoidCallback? onRemove;

  @override
  State<_ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends State<_ImageField> {
  bool _uploading = false;
  bool _showUrl = false;

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      final url = await widget.onPickImage();
      if (url != null) widget.onChanged(url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasImage = widget.value.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
              child: Container(
                width: 64,
                height: 64,
                color: AppColors.surfaceTint,
                child: hasImage
                    ? Image.network(
                        resolveImageUrl(widget.value),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => AppIcon(
                          AppIcons.brokenImageOutlined,
                          color: AppColors.muted,
                        ),
                      )
                    : AppIcon(AppIcons.imageOutlined, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodySmall?.semibold,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _upload,
                        icon: _uploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const AppIcon(AppIcons.uploadRounded, size: 16),
                        label: Text(
                          hasImage ? l10n.productsReplace : l10n.productsUpload,
                        ),
                      ),
                      if (hasImage && widget.onRemove != null)
                        IconButton(
                          icon: const AppIcon(AppIcons.deleteOutline, size: 20),
                          tooltip: l10n.productsRemove,
                          onPressed: widget.onRemove,
                        ),
                    ],
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _showUrl = !_showUrl),
                    child: Text(
                      _showUrl
                          ? l10n.productsHideLinkField
                          : l10n.productsOrPasteLink,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_showUrl) ...[
          const SizedBox(height: 6),
          TextFormField(
            initialValue: widget.value,
            onChanged: widget.onChanged,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.productsImageLinkUrl,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _TextLine extends StatelessWidget {
  const _TextLine({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLength,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  const _TextArea({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLength,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      maxLength: maxLength,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
