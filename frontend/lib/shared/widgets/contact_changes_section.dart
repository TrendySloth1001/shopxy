import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';

/// Audit trail of edits to a Party's or Vendor's contact details.
/// Fetches `<endpoint>/changes` and renders a timeline of
/// "field: old → new · by user · timestamp" rows.
///
/// Single source of truth — used by both party_detail_page and
/// vendor_detail_page. We render nothing (zero space) when the entity
/// has never been edited, so detail pages can include this
/// unconditionally without an empty-state hole.
class ContactChangesSection extends StatefulWidget {
  const ContactChangesSection({super.key, required this.endpoint});

  /// Path to the entity, e.g. `/parties/123` or `/vendors/456`. We
  /// append `/changes` ourselves so callers don't have to remember the
  /// suffix.
  final String endpoint;

  @override
  State<ContactChangesSection> createState() => _ContactChangesSectionState();
}

class _ContactChangesSectionState extends State<ContactChangesSection> {
  static final _fmt = DateFormat('d MMM y, h:mm a');

  List<_ChangeEntry>? _entries;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = context.read<ApiClient>();
      final res = await client.get(
        '${widget.endpoint}/changes',
        queryParameters: const {'limit': '20'},
      );
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>;
      final parsed = data
          .map((e) => _ChangeEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _entries = parsed;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _entries = null;
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_error != null) return const SizedBox.shrink();
    final entries = _entries;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'Recent changes'),
        const AppDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  if (i > 0) const AppDivider.flush(),
                  _ChangeRow(entry: entries[i], dateFmt: _fmt),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.xl),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.entry, required this.dateFmt});
  final _ChangeEntry entry;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actor = entry.changedByName;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.surfaceTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              _iconFor(entry.field),
              size: 14,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                    ),
                    children: [
                      TextSpan(
                        text: _labelFor(entry.field),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' changed'),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_displayValue(entry.oldValue)}  →  ${_displayValue(entry.newValue)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  actor == null
                      ? dateFmt.format(entry.changedAt.toLocal())
                      : '${dateFmt.format(entry.changedAt.toLocal())} · by $actor',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.subtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _displayValue(String? v) {
    if (v == null || v.isEmpty) return '—';
    return v;
  }

  static String _labelFor(String field) {
    switch (field) {
      case 'name':
        return 'Name';
      case 'contactName':
        return 'Contact person';
      case 'phone':
        return 'Phone';
      case 'email':
        return 'Email';
      case 'address':
        return 'Address';
      case 'city':
        return 'City';
      case 'state':
        return 'State';
      case 'stateCode':
        return 'State code';
      case 'pinCode':
        return 'PIN code';
      case 'panNumber':
        return 'PAN';
      case 'gstin':
        return 'GSTIN';
      case 'isActive':
        return 'Active';
      default:
        return field;
    }
  }

  static IconData _iconFor(String field) {
    switch (field) {
      case 'phone':
        return Icons.phone_rounded;
      case 'email':
        return Icons.email_rounded;
      case 'address':
      case 'city':
      case 'state':
      case 'stateCode':
      case 'pinCode':
        return Icons.place_rounded;
      case 'gstin':
      case 'panNumber':
        return Icons.badge_rounded;
      case 'name':
      case 'contactName':
        return Icons.person_rounded;
      case 'isActive':
        return Icons.toggle_on_rounded;
      default:
        return Icons.edit_rounded;
    }
  }
}

class _ChangeEntry {
  _ChangeEntry({
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.changedAt,
    this.changedByName,
  });

  final String field;
  final String? oldValue;
  final String? newValue;
  final DateTime changedAt;
  final String? changedByName;

  factory _ChangeEntry.fromJson(Map<String, dynamic> j) {
    final by = j['changedBy'] as Map<String, dynamic>?;
    return _ChangeEntry(
      field: j['field'] as String,
      oldValue: j['oldValue'] as String?,
      newValue: j['newValue'] as String?,
      changedAt: DateTime.parse(j['changedAt'] as String),
      changedByName: by == null ? null : by['name'] as String?,
    );
  }
}
