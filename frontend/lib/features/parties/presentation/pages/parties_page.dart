import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/presentation/providers/parties_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key});

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PartiesProvider>().loadParties();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PartiesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navParties),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: AppStrings.addParty,
            onPressed: () => _showPartySheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              0,
            ),
            child: AppSearchBar(
              hint: AppStrings.searchParties,
              onChanged: context.read<PartiesProvider>().updateSearch,
            ),
          ),
          Expanded(
            child: provider.isLoading && provider.parties.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && provider.parties.isEmpty
                    ? EmptyState.line(
                        kind: LineArt.warning,
                        title: AppStrings.error,
                        action: AppButton.secondary(
                          label: AppStrings.retry,
                          onPressed: () => context
                              .read<PartiesProvider>()
                              .loadParties(refresh: true),
                        ),
                      )
                    : provider.parties.isEmpty
                        ? EmptyState.line(
                            kind: LineArt.customers,
                            title: AppStrings.noParties,
                            subtitle: AppStrings.noPartiesHint,
                            action: AppButton.primary(
                              label: AppStrings.addParty,
                              icon: Icons.add_rounded,
                              onPressed: () => _showPartySheet(context),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => context
                                .read<PartiesProvider>()
                                .loadParties(refresh: true),
                            color: AppColors.black,
                            backgroundColor: AppColors.white,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSizes.sm,
                              ),
                              itemCount: provider.parties.length,
                              separatorBuilder: (_, _) => const AppDivider(),
                              itemBuilder: (context, i) => _PartyTile(
                                party: provider.parties[i],
                                onEdit: () => _showPartySheet(
                                  context,
                                  party: provider.parties[i],
                                ),
                                onDelete: () =>
                                    _confirmDelete(context, provider.parties[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showPartySheet(BuildContext context, {Party? party}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      builder: (_) => PartyFormSheet(party: party),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Party party) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: AppStrings.deleteParty,
      message: '${AppStrings.deletePartyConfirm} "${party.name}"?',
      confirmLabel: AppStrings.delete,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<PartiesProvider>().deleteParty(party.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.partyDeleted)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _PartyTile extends StatelessWidget {
  const _PartyTile({
    required this.party,
    required this.onEdit,
    required this.onDelete,
  });
  final Party party;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onEdit,
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            children: [
              AppMonogramAvatar(label: party.name),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (party.phone != null)
                      Text(
                        party.phone!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    if (party.gstin != null)
                      Text(
                        'GSTIN: ${party.gstin}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    const SizedBox(height: AppSizes.xs),
                    Wrap(
                      spacing: AppSizes.xs,
                      runSpacing: 4,
                      children: [
                        AppStatusBadge(
                          label: '${party.challanCount} challans',
                          icon: Icons.description_outlined,
                          dense: true,
                        ),
                        AppStatusBadge(
                          label: '${party.invoiceCount} invoices',
                          icon: Icons.receipt_outlined,
                          dense: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                onPressed: () => _showMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(AppStrings.edit),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                AppStrings.delete,
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PartyFormSheet extends StatefulWidget {
  const PartyFormSheet({super.key, this.party});
  final Party? party;

  @override
  State<PartyFormSheet> createState() => _PartyFormSheetState();
}

class _PartyFormSheetState extends State<PartyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  late final TextEditingController _name;
  late final TextEditingController _contactName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _gstin;

  bool get isEditing => widget.party != null;

  @override
  void initState() {
    super.initState();
    final p = widget.party;
    _name = TextEditingController(text: p?.name ?? '');
    _contactName = TextEditingController(text: p?.contactName ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _gstin = TextEditingController(text: p?.gstin ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _gstin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<PartiesProvider>();
      Party saved;
      if (isEditing) {
        saved = await provider.updateParty(
          widget.party!.id,
          name: _name.text,
          contactName: _contactName.text,
          phone: _phone.text,
          email: _email.text,
          address: _address.text,
          gstin: _gstin.text,
        );
      } else {
        saved = await provider.createParty(
          name: _name.text,
          contactName:
              _contactName.text.isNotEmpty ? _contactName.text : null,
          phone: _phone.text.isNotEmpty ? _phone.text : null,
          email: _email.text.isNotEmpty ? _email.text : null,
          address: _address.text.isNotEmpty ? _address.text : null,
          gstin: _gstin.text.isNotEmpty ? _gstin.text : null,
        );
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSizes.lg,
        right: AppSizes.lg,
        top: AppSizes.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: LineIllustration(
                  kind: LineArt.customers,
                  size: 88,
                  accent: AppColors.brand,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                isEditing ? AppStrings.editParty : AppStrings.addParty,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.lg),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: AppStrings.partyName,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? AppStrings.fieldRequired
                    : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _contactName,
                decoration: const InputDecoration(
                  labelText: AppStrings.contactName,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: AppStrings.phone,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: AppStrings.email,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _gstin,
                decoration: const InputDecoration(labelText: AppStrings.gstin),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: AppStrings.address,
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSizes.xl),
              AppButton.primary(
                label: AppStrings.save,
                onPressed: _save,
                isLoading: _isSaving,
                size: AppButtonSize.lg,
                fullWidth: true,
              ),
              const SizedBox(height: AppSizes.xl),
            ],
          ),
        ),
      ),
    );
  }
}
