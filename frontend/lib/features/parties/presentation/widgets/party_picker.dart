import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/presentation/pages/parties_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Opens a modal search sheet to pick an existing Party or create a new one.
/// Returns the selected [Party], or null if cancelled.
Future<Party?> showPartyPicker(BuildContext context) {
  return showModalBottomSheet<Party>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    builder: (_) => const _PartyPickerSheet(),
  );
}

class _PartyPickerSheet extends StatefulWidget {
  const _PartyPickerSheet();

  @override
  State<_PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends State<_PartyPickerSheet> {
  final _search = TextEditingController();
  List<Party> _parties = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<PartiesRemoteDataSource>();
      final results = await ds.getParties(
        search: query.isNotEmpty ? query : null,
        limit: 20,
      );
      if (mounted) setState(() => _parties = results);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addNew() async {
    final created = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      builder: (_) => const PartyFormSheet(),
    );
    if (created != null && mounted) {
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height * 0.8;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSizes.md),
            Container(
              width: AppSizes.handleWidth,
              height: AppSizes.handleHeight,
              decoration: ShapeDecoration(
                color: AppColors.hairline,
                shape: AppShapes.squircle(AppSizes.radiusFull),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Row(
                children: [
                  Text(
                    AppStrings.selectParty,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  AppButton.ghost(
                    label: AppStrings.newParty,
                    icon: Icons.add_rounded,
                    onPressed: _addNew,
                    size: AppButtonSize.sm,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: AppStrings.searchParties,
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: _load,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Expanded(
              child: _loading && _parties.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _parties.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSizes.xl),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.groups_outlined,
                                      size: AppSizes.iconXl,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(height: AppSizes.md),
                                    Text(
                                      AppStrings.noParties,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: AppSizes.md),
                                    AppButton.primary(
                                      label: AppStrings.addParty,
                                      icon: Icons.add_rounded,
                                      onPressed: _addNew,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _parties.length,
                              separatorBuilder: (_, _) => const AppDivider(),
                              itemBuilder: (context, i) {
                                final p = _parties[i];
                                return ListTile(
                                  leading: AppMonogramAvatar(label: p.name),
                                  title: Text(p.name),
                                  subtitle: Text(p.phone ?? p.contactName ?? '—'),
                                  onTap: () => Navigator.pop(context, p),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
