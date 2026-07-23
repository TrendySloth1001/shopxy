import 'package:flutter/material.dart';
import 'package:shopxy/features/profile/presentation/pages/legal_content.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// The Privacy Policy / Terms of Service reader. Both flavours share this
/// scaffolding; the body is a verbatim copy of the merchant-web legal pages
/// (see [kPrivacySections] / [kTermsSections] in legal_content.dart) so the
/// mobile and web legal text stay identical.
class LegalPage extends StatelessWidget {
  const LegalPage.privacy({super.key}) : _isPrivacy = true;

  const LegalPage.terms({super.key}) : _isPrivacy = false;

  final bool _isPrivacy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title =
        _isPrivacy ? l10n.profilePrivacyPolicy : l10n.profileTermsOfService;
    final sections = _isPrivacy ? kPrivacySections : kTermsSections;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: title),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.lg + FloatingAppBar.contentTopInset(context),
          AppSizes.lg,
          AppSizes.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kLegalUpdated,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.subtle,
              ),
            ),
            for (final section in sections) _SectionView(section: section),
          ],
        ),
      ),
    );
  }
}

/// One legal section — a hairline rule, its heading, then its blocks
/// (mirrors the web `LegalSection`: `border-t` + heading + prose).
class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});
  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppDivider.flush(),
          const SizedBox(height: AppSizes.md),
          Text(
            section.heading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          for (final block in section.blocks) _BlockView(block: block),
        ],
      ),
    );
  }
}

/// A paragraph or a bulleted list within a section.
class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});
  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.muted,
      height: 1.5,
    );
    final paragraph = block.paragraph;
    if (paragraph != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.sm),
        child: Text(paragraph, style: style),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in block.bullets!)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: style),
                  Expanded(child: Text(item, style: style)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
