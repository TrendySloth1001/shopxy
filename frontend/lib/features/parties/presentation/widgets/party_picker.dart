import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/presentation/pages/parties_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

/// Opens a modal search sheet to pick an existing Party or create a new one.
/// Returns the selected [Party], or null if cancelled.
Future<Party?> showPartyPicker(BuildContext context) {
  return showModalBottomSheet<Party>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
    setState(() { _loading = true; _error = null; });
    try {
      final ds = context.read<PartiesRemoteDataSource>();
      final results = await ds.getParties(
        search: query.isNotEmpty ? query : null,
        limit: 20,
      );
      if (mounted) setState(() => _parties = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addNew() async {
    final created = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Row(
                children: [
                  Text(
                    AppStrings.selectParty,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addNew,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(AppStrings.newParty),
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
                                    Icon(
                                      Icons.groups_outlined,
                                      size: 48,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: AppSizes.md),
                                    Text(
                                      AppStrings.noParties,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: AppSizes.md),
                                    FilledButton.icon(
                                      onPressed: _addNew,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text(AppStrings.addParty),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _parties.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final p = _parties[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: theme.colorScheme.secondaryContainer,
                                    child: Text(
                                      p.name.characters.first.toUpperCase(),
                                      style: TextStyle(
                                        color: theme.colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
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
