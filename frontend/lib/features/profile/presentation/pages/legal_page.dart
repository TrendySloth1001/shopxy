import 'package:flutter/material.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// Static legal/about copy. Two flavours (privacy + terms) share the
/// same scaffolding because the only thing that differs is the body
/// text and the title — keeping them as one widget avoids duplication
/// and keeps the surface tiny until we wire a CMS or remote source.
class LegalPage extends StatelessWidget {
  const LegalPage.privacy({super.key}) : _isPrivacy = true;

  const LegalPage.terms({super.key}) : _isPrivacy = false;

  final bool _isPrivacy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title =
        _isPrivacy ? l10n.profilePrivacyPolicy : l10n.profileTermsOfService;
    final body = _isPrivacy ? l10n.profilePrivacyBody : l10n.profileTermsBody;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: title),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.lg + FloatingAppBar.contentTopInset(context),
          AppSizes.lg,
          AppSizes.lg,
        ),
        child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
