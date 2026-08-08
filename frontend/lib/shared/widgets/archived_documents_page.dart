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

/// One screen shape for every `Archived …` view — invoices, challans,
/// quotations.
///
/// Archiving means the same thing for all three: the document leaves the
/// working list and KEEPS its number, because each number is a per-shop
/// serial allocated at create time and a run with a hole in it is a problem
/// with an auditor. None of them can be deleted, so this screen is the only
/// way back.
///
/// Single-sourced rather than copied per feature so the three can't drift —
/// the filter strip, the day grouping, the restore affordance and the empty
/// state are decided once here.
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

  /// Fetches the archived page for the selected filter (null = "All").
  final Future<List<T>> Function(String? filter) load;

  /// Brings one document back. Throwing surfaces as a snack bar.
  final Future<void> Function(T item) restore;

  final ArchivedRowData Function(T item) rowOf;

  /// The date rows are grouped by. Must be the field the server sorts on,
  /// otherwise a day heading repeats further down the scroll.
  final DateTime Function(T item) dateOf;

  /// Opens the detail screen. Awaited, then the list reloads — the detail
  /// screen can restore the document, which takes it out of this list.
  final Future<void> Function(BuildContext context, T item) onOpen;

  final String emptyTitle;
  final String emptyBody;

  /// Optional pills above the list. The first should be the "All" entry
  /// (`value: null`). Empty means no strip is drawn.
  final List<ArchivedFilter> filters;

  @override
  State<ArchivedDocumentsPage<T>> createState() =>
      _ArchivedDocumentsPageState<T>();
}

/// A pill in the filter strip. [value] is passed straight to `load`.
class ArchivedFilter {
  const ArchivedFilter({required this.label, this.value, this.icon});
  final String label;
  final String? value;
  final AppIconData? icon;
}

/// The parts of an archived row that differ per document kind. Everything
/// else — layout, the retained-number chip, the restore button — is fixed.
class ArchivedRowData {
  const ArchivedRowData({
    required this.number,
    required this.status,
    required this.subtitle,
    this.trailing,
  });

  /// The serial that stays allocated. The reason archiving exists.
  final String number;
  final String status;

  /// Counterparty, usually.
  final String subtitle;

  /// Right-hand figure — a total, an item count. Omitted when there isn't one.
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
      // Indices shift when a row goes, so the busy set is cleared wholesale
      // rather than having stale entries point at the wrong rows.
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
                        // Tapping the active pill clears back to All.
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
      // Always scrollable so pull-to-refresh still works on an empty list.
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
                    // The number is the point: it stays allocated, which is
                    // what makes archiving workable where deleting wasn't.
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
                // The date lives in the day divider above, so the row keeps
                // only what differs between rows in the same group.
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
