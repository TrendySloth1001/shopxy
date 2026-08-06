import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:shopxy/features/pdf_templates/data/datasources/pdf_templates_remote_data_source.dart';
import 'package:shopxy/features/pdf_templates/domain/entities/pdf_template.dart';
import 'package:shopxy/features/pdf_templates/presentation/providers/pdf_templates_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class PdfTemplatesPage extends StatefulWidget {
  const PdfTemplatesPage({super.key});

  @override
  State<PdfTemplatesPage> createState() => _PdfTemplatesPageState();
}

class _PdfTemplatesPageState extends State<PdfTemplatesPage> {
  String? _previewingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PdfTemplatesProvider>().load();
      final shop = context.read<ShopProvider>();
      if (shop.shop == null) shop.load();
    });
  }

  Future<void> _select(PdfTemplate tpl) async {
    final shop = context.read<ShopProvider>();
    if (shop.shop?.pdfTemplateId == tpl.id || shop.isSaving) return;
    final ok = await shop.save(pdfTemplateId: tpl.id);
    if (!mounted) return;
    if (!ok && shop.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(shop.error!)));
    }
  }

  Future<void> _preview(PdfTemplate tpl) async {
    setState(() => _previewingId = tpl.id);
    try {
      final ds = context.read<PdfTemplatesRemoteDataSource>();
      final response = await ds.sample(tpl.id);
      if (response.statusCode != 200) {
        throw Exception('Failed to generate preview');
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/template-${tpl.id}-sample.pdf');
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _previewingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<PdfTemplatesProvider>();
    final shop = context.watch<ShopProvider>();
    final selectedId = shop.shop?.pdfTemplateId ?? 'classic';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.pdfTemplatesTitle),
      body: provider.isLoading && !provider.hasLoadedOnce
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && provider.templates.isEmpty
          ? AppErrorView(onRetry: () => provider.load())
          : GridView.builder(
              padding: EdgeInsets.fromLTRB(
                AppSizes.lg,
                FloatingAppBar.contentTopInset(context) + AppSizes.md,
                AppSizes.lg,
                AppSizes.huge,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSizes.md,
                mainAxisSpacing: AppSizes.md,
                childAspectRatio: 0.82,
              ),
              itemCount: provider.templates.length,
              itemBuilder: (context, i) {
                final tpl = provider.templates[i];
                return _TemplateCard(
                  template: tpl,
                  selected: tpl.id == selectedId,
                  busy: shop.isSaving,
                  previewing: _previewingId == tpl.id,
                  onTap: () => _select(tpl),
                  onPreview: () => _preview(tpl),
                );
              },
            ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.busy,
    required this.previewing,
    required this.onTap,
    required this.onPreview,
  });

  final PdfTemplate template;
  final bool selected;
  final bool busy;
  final bool previewing;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: BorderSide(
          color: selected ? AppColors.brand : AppColors.hairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 480 / 284,
                  child: Image.asset(
                    'assets/template_thumbnails/${template.id}.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                if (selected)
                  Positioned(
                    top: AppSizes.xs,
                    right: AppSizes.xs,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(
                        AppIcons.checkRounded,
                        size: 16,
                        color: AppColors.onInverse,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    template.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    template.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  AppButton.secondary(
                    label: l10n.pdfTemplatesPreview,
                    icon: AppIcons.visibilityOutlined,
                    size: AppButtonSize.sm,
                    isLoading: previewing,
                    onPressed: previewing ? null : onPreview,
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
