import 'package:flutter/material.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_filter_pill.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/widgets/section_divider.dart';

class ArchivedDocumentsPage<T> extends StatefulWidget {
  const ArchivedDocumentsPage({
    super.key,
    required this.title,
    required this.load,
    required this.restore,
    required this.rowOf,
    required this.dateOf,
    required this.onOpen,
    required this.emptyTitle,
    required this.emptyBody,
    this.filters = const [],
  });

  final String title;

  final Future<List<T>> Function(String? filter) load;

  final Future<void> Function(T item) restore;

  final ArchivedRowData Function(T item) rowOf;

  final DateTime Function(T item) dateOf;

  final Future<void> Function(BuildContext context, T item) onOpen;

  final String emptyTitle;
  final String emptyBody;

  final List<ArchivedFilter> filters;

  @override
  State<ArchivedDocumentsPage<T>> createState() =>
      _ArchivedDocumentsPageState<T>();
}

class ArchivedFilter {
  const ArchivedFilter({required this.label, this.value, this.icon});
  final String label;
  final String? value;
  final AppIconData? icon;
}

class ArchivedRowData {
  const ArchivedRowData({
    required this.number,
    required this.status,
    required this.subtitle,
    this.trailing,
  });

  final String number;
  final String status;

  final String subtitle;

  final String? trailing;
}

class _ArchivedDocumentsPageState<T> extends State<ArchivedDocumentsPage<T>> {
  List<T> _items = [];
  bool _loading = true;
  String? _error;
  String? _filter;
  final _restoring = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.load(_filter);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  void _setFilter(String? value) {
    if (_filter == value) return;
    setState(() => _filter = value);
    _load();
  }

  Future<void> _restore(int index) async {
    if (_restoring.contains(index)) return;
    final messenger = ScaffoldMessenger.of(context);
    final item = _items[index];
    setState(() => _restoring.add(index));
    try {
      await widget.restore(item);
      if (!mounted) return;
      setState(() {
        _items = List.of(_items)..removeAt(index);
        _restoring.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoring.remove(index));
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: widget.title),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            if (widget.filters.isNotEmpty) ...[
              AppFilterStrip(
                children: [
                  for (final f in widget.filters)
                    AppFilterPill(
                      label: f.label,
                      icon: f.icon,
                      selected: _filter == f.value,
                      onTap: () => _setFilter(
                        _filter == f.value ? null : f.value,
                      ),
                    ),
                ],
              ),
              const AppDivider.flush(),
            ],
            Expanded(
              child: RefreshIndicator(onRefresh: _load, child: _body()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorView(message: _error, onRetry: _load);
    }
    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: AppSizes.huge),
        children: [
          EmptyState(
            icon: AppIcons.archiveOutlined,
            title: widget.emptyTitle,
            subtitle: widget.emptyBody,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.huge,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (context, i) {
        final item = _items[i];
        final newDay =
            i == 0 ||
            !SectionDivider.isSameDay(
              widget.dateOf(item),
              widget.dateOf(_items[i - 1]),
            );
        final tile = _ArchivedRow(
          data: widget.rowOf(item),
          busy: _restoring.contains(i),
          onOpen: () async {
            await widget.onOpen(context, item);
            if (mounted) await _load();
          },
          onRestore: () => _restore(i),
        );
        if (!newDay) return tile;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SectionDivider.date(widget.dateOf(item)), tile],
        );
      },
    );
  }
}

class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({
    required this.data,
    required this.busy,
    required this.onOpen,
    required this.onRestore,
  });

  final ArchivedRowData data;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      onTap: onOpen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        data.number,
                        style: theme.textTheme.bodyMedium?.semibold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.sm,
                        vertical: 1,
                      ),
                      decoration: ShapeDecoration(
                        color: AppColors.heroPanel,
                        shape: AppShapes.squircle(AppSizes.radiusFull),
                      ),
                      child: Text(
                        data.status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (data.trailing != null)
                Text(data.trailing!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 2),
              busy
                  ? const SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      onPressed: onRestore,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: AppIcon(
                        AppIcons.unarchiveRounded,
                        size: AppSizes.iconSm,
                        color: AppColors.brandStrong,
                      ),
                      label: Text(
                        l10n.actionRestore,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.brandStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
