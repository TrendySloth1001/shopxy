import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/shop/data/models/shop.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

const _dayCodes = <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayLabels = <String, String>{
  'mon': 'Monday',
  'tue': 'Tuesday',
  'wed': 'Wednesday',
  'thu': 'Thursday',
  'fri': 'Friday',
  'sat': 'Saturday',
  'sun': 'Sunday',
};

/// Editor for `Shop.operatingHours` + `Shop.vacationMode` +
/// `Shop.vacationMessage`. Vacation mode at the top — it's the most
/// common reason a merchant lands on this page (they're going on
/// leave). Below: a per-day open/close picker; toggle the day off
/// to remove it from the map (= closed).
class ShopHoursPage extends StatefulWidget {
  const ShopHoursPage({super.key});

  @override
  State<ShopHoursPage> createState() => _ShopHoursPageState();
}

class _ShopHoursPageState extends State<ShopHoursPage> {
  late final TextEditingController _vacationMessage;
  late bool _vacationMode;
  late Map<String, _DayHours> _hours;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _vacationMessage = TextEditingController();
    _vacationMode = false;
    _hours = {for (final d in _dayCodes) d: const _DayHours(closed: true)};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopProvider>().load();
    });
  }

  @override
  void dispose() {
    _vacationMessage.dispose();
    super.dispose();
  }

  void _hydrate(Shop shop) {
    if (_initialised) return;
    _initialised = true;
    _vacationMode = shop.vacationMode;
    _vacationMessage.text = shop.vacationMessage ?? '';
    final stored = shop.operatingHours;
    if (stored != null) {
      for (final d in _dayCodes) {
        final v = stored[d];
        if (v != null && v.length == 2) {
          _hours[d] = _DayHours(
            closed: false,
            open: _parseTime(v[0]),
            close: _parseTime(v[1]),
          );
        }
      }
    }
  }

  Future<void> _save(Shop shop) async {
    final body = <String, List<String>>{};
    for (final entry in _hours.entries) {
      final hours = entry.value;
      if (!hours.closed && hours.open != null && hours.close != null) {
        body[entry.key] = [
          _fmtTime(hours.open!),
          _fmtTime(hours.close!),
        ];
      }
    }
    final provider = context.read<ShopProvider>();
    final ok = await provider.save(
      vacationMode: _vacationMode,
      vacationMessage:
          _vacationMessage.text.trim().isEmpty ? null : _vacationMessage.text.trim(),
      operatingHours: body.isEmpty ? null : body,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Hours saved' : provider.error ?? 'Save failed'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShopProvider>();
    final shop = provider.shop;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Hours & vacation mode'),
        actions: [
          if (shop != null)
            TextButton(
              onPressed: provider.isSaving ? null : () => _save(shop),
              child: Text(provider.isSaving ? 'Saving…' : 'Save'),
            ),
        ],
      ),
      body: shop == null
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(shop),
    );
  }

  Widget _buildForm(Shop shop) {
    _hydrate(shop);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.huge),
      children: [
        Material(
          color: _vacationMode
              ? AppColors.warningSoft
              : AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _vacationMode,
                  onChanged: (v) => setState(() => _vacationMode = v),
                  title: const Text(
                    'Vacation mode',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Blocks new orders. Existing orders, stock, and '
                    'invoices stay editable as usual.',
                  ),
                ),
                if (_vacationMode) ...[
                  const SizedBox(height: AppSizes.sm),
                  TextField(
                    controller: _vacationMessage,
                    decoration: const InputDecoration(
                      labelText: 'Message shown to customers (optional)',
                      hintText: 'e.g. Back on Jun 5. Thanks for your patience!',
                    ),
                    maxLength: 280,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.xl),
        Text(
          'OPENING HOURS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: AppSizes.sm),
        Material(
          color: AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusMd),
          child: Column(
            children: [
              for (var i = 0; i < _dayCodes.length; i++) ...[
                if (i != 0)
                  const Divider(
                    height: 1,
                    color: AppColors.hairline,
                    indent: AppSizes.md,
                    endIndent: AppSizes.md,
                  ),
                _DayRow(
                  label: _dayLabels[_dayCodes[i]]!,
                  hours: _hours[_dayCodes[i]]!,
                  onChange: (next) {
                    setState(() => _hours[_dayCodes[i]] = next);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        const Text(
          'Hours are a hint to customers — orders outside hours still '
          'go through.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  static TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DayHours {
  const _DayHours({
    required this.closed,
    this.open,
    this.close,
  });
  final bool closed;
  final TimeOfDay? open;
  final TimeOfDay? close;
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.hours,
    required this.onChange,
  });
  final String label;
  final _DayHours hours;
  final ValueChanged<_DayHours> onChange;

  Future<void> _pickTime(BuildContext context, bool isOpen) async {
    final t = await showTimePicker(
      context: context,
      initialTime: (isOpen ? hours.open : hours.close) ??
          const TimeOfDay(hour: 9, minute: 0),
    );
    if (t == null) return;
    onChange(_DayHours(
      closed: false,
      open: isOpen ? t : (hours.open ?? const TimeOfDay(hour: 9, minute: 0)),
      close: isOpen
          ? (hours.close ?? const TimeOfDay(hour: 21, minute: 0))
          : t,
    ));
  }

  String _fmt(TimeOfDay? t) {
    if (t == null) return '—';
    final hr = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final min = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return '$hr:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: hours.closed
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Closed',
                      style: TextStyle(
                          color: AppColors.muted, fontStyle: FontStyle.italic),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickTime(context, true),
                          child: Text(_fmt(hours.open)),
                        ),
                      ),
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSizes.xs),
                        child: Text('–'),
                      ),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickTime(context, false),
                          child: Text(_fmt(hours.close)),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: AppSizes.sm),
          Switch.adaptive(
            value: !hours.closed,
            onChanged: (v) {
              onChange(
                v
                    ? _DayHours(
                        closed: false,
                        open: hours.open ?? const TimeOfDay(hour: 9, minute: 0),
                        close:
                            hours.close ?? const TimeOfDay(hour: 21, minute: 0),
                      )
                    : const _DayHours(closed: true),
              );
            },
          ),
        ],
      ),
    );
  }
}
