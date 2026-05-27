import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

/// Phase C — A+ content blocks editor used inside the add/edit product
/// page. Each block is one of HERO / FEATURE / COMPARISON / GALLERY /
/// TEXT (mirrors the backend `contentBlockSchema`). Hard cap 8 blocks
/// enforced client + server.
///
/// The editor reads/writes [blocks] in place: the parent owns the list,
/// the widget mutates it directly. Same pattern used by [_SpecsEditor]
/// and [_OffersEditor] elsewhere in this file's neighbourhood.
class ContentBlocksEditor extends StatefulWidget {
  const ContentBlocksEditor({
    super.key,
    required this.blocks,
    required this.onChange,
  });
  final List<ContentBlock> blocks;
  final VoidCallback onChange;

  @override
  State<ContentBlocksEditor> createState() => _ContentBlocksEditorState();
}

class _ContentBlocksEditorState extends State<ContentBlocksEditor> {
  static const _maxBlocks = 8;

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
        'FEATURE' => {
            'imageUrl': '',
            'side': 'LEFT',
            'title': '',
            'body': '',
          },
        'COMPARISON' => {
            'columns': [
              {'label': 'Hydra 10', 'values': <String>['']},
              {'label': 'Hydra 9', 'values': <String>['']},
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.blocks.length; i++)
          _BlockCard(
            block: widget.blocks[i],
            index: i,
            total: widget.blocks.length,
            onUpdate: (next) => _update(i, next),
            onRemove: () => _remove(i),
            onUp: () => _move(i, -1),
            onDown: () => _move(i, 1),
          ),
        if (widget.blocks.length < _maxBlocks) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in const ['HERO', 'FEATURE', 'COMPARISON', 'GALLERY', 'TEXT'])
                OutlinedButton.icon(
                  onPressed: () => _add(k),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Add $k'),
                ),
            ],
          ),
        ],
      ],
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
  });
  final ContentBlock block;
  final int index;
  final int total;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final VoidCallback onRemove;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.heroPanel,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  block.kind,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text('Block ${index + 1} / $total',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12)),
              const Spacer(),
              IconButton(
                tooltip: 'Move up',
                onPressed: index == 0 ? null : onUp,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: index == total - 1 ? null : onDown,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _BlockForm(block: block, onUpdate: onUpdate),
        ],
      ),
    );
  }
}

class _BlockForm extends StatelessWidget {
  const _BlockForm({required this.block, required this.onUpdate});
  final ContentBlock block;
  final ValueChanged<Map<String, dynamic>> onUpdate;

  Map<String, dynamic> _patch(Map<String, dynamic> patch) =>
      {...block.data, ...patch};

  @override
  Widget build(BuildContext context) {
    switch (block.kind) {
      case 'HERO':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UrlField(
              label: 'Image URL',
              value: block.data['imageUrl'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'imageUrl': v})),
            ),
            const SizedBox(height: 8),
            _TextLine(
              label: 'Headline',
              value: block.data['headline'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'headline': v})),
              maxLength: 120,
            ),
            const SizedBox(height: 8),
            _TextLine(
              label: 'Subtext (optional)',
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
            _UrlField(
              label: 'Image URL',
              value: block.data['imageUrl'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'imageUrl': v})),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Image side: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: (block.data['side'] as String?) ?? 'LEFT',
                  items: const [
                    DropdownMenuItem(value: 'LEFT', child: Text('LEFT')),
                    DropdownMenuItem(value: 'RIGHT', child: Text('RIGHT')),
                  ],
                  onChanged: (v) =>
                      v == null ? null : onUpdate(_patch({'side': v})),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TextLine(
              label: 'Title',
              value: block.data['title'] as String? ?? '',
              onChanged: (v) => onUpdate(_patch({'title': v})),
              maxLength: 120,
            ),
            const SizedBox(height: 8),
            _TextArea(
              label: 'Body',
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
              Row(
                children: [
                  Expanded(
                    child: _UrlField(
                      label: 'Image ${i + 1} URL',
                      value: imgs[i]['url'] as String? ?? '',
                      onChanged: (v) {
                        imgs[i] = {...imgs[i], 'url': v};
                        onUpdate(_patch({'images': imgs}));
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      imgs.removeAt(i);
                      onUpdate(_patch({'images': imgs}));
                    },
                  ),
                ],
              ),
              _TextLine(
                label: 'Caption (optional)',
                value: imgs[i]['caption'] as String? ?? '',
                onChanged: (v) {
                  imgs[i] = {...imgs[i], 'caption': v};
                  onUpdate(_patch({'images': imgs}));
                },
                maxLength: 140,
              ),
              const SizedBox(height: 8),
            ],
            if (imgs.length < 6)
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add image'),
                onPressed: () {
                  imgs.add({'url': ''});
                  onUpdate(_patch({'images': imgs}));
                },
              ),
          ],
        );
      case 'COMPARISON':
        // Hand the merchant a JSON-like textarea for compact editing —
        // a full per-cell editor would balloon the form. We re-parse
        // on every keystroke when the JSON is valid; invalid drafts
        // are kept verbatim under _draft so the merchant doesn't lose
        // their work mid-typing. The server re-validates with Zod and
        // returns 400 if the shape is bad.
        return _TextArea(
          label: 'Comparison JSON (columns + rows)',
          value: (block.data['_draft'] as String?) ??
              _stringifyComparison(block.data),
          onChanged: (v) {
            try {
              final parsed = jsonDecode(v) as Map<String, dynamic>;
              onUpdate({
                'columns': parsed['columns'] ?? const [],
                'rows': parsed['rows'] ?? const [],
                '_draft': v,
              });
            } catch (_) {
              onUpdate(_patch({'_draft': v}));
            }
          },
          maxLength: 2000,
        );
      case 'TEXT':
      default:
        return _TextArea(
          label: 'Markdown',
          value: block.data['markdown'] as String? ?? '',
          onChanged: (v) => onUpdate(_patch({'markdown': v})),
          maxLength: 2000,
        );
    }
  }

  String _stringifyComparison(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert({
        'columns': data['columns'] ?? const [],
        'rows': data['rows'] ?? const [],
      });
}

class _UrlField extends StatelessWidget {
  const _UrlField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
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
