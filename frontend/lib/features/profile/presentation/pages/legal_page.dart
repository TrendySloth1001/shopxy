import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

/// Static legal/about copy. Two flavours (privacy + terms) share the
/// same scaffolding because the only thing that differs is the body
/// text and the title — keeping them as one widget avoids duplication
/// and keeps the surface tiny until we wire a CMS or remote source.
class LegalPage extends StatelessWidget {
  const LegalPage.privacy({super.key})
      : _title = AppStrings.privacyPolicy,
        _body = _privacyBody;

  const LegalPage.terms({super.key})
      : _title = AppStrings.termsOfService,
        _body = _termsBody;

  final String _title;
  final String _body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Text(_body, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

const String _privacyBody = '''
ShopXY stores the minimum data needed to run your shop: account credentials, your product/vendor/party records, invoices you create, and notification preferences. Data is held on infrastructure under our control and is never sold.

We do not share your data with third parties except as required to operate the service (payment processors, hosting providers, error monitoring) or by law.

You can request a copy or deletion of your data by emailing support. Account deletion removes user-bound rows and revokes all sessions.

This is a placeholder policy intended for in-app review. A full legal document will replace this text before any public release.
''';

const String _termsBody = '''
ShopXY is provided as-is for managing your shop's inventory, invoices and customer relationships. By using the app you agree to:

1. Provide accurate information when creating an account.
2. Keep your password confidential. You are responsible for all activity under your account.
3. Not abuse the service: no spam, no scraping, no attempts to compromise other accounts.
4. Comply with applicable tax and commerce laws in your jurisdiction.

We may suspend accounts that violate these terms or that we reasonably suspect of fraudulent activity.

This is a placeholder document for in-app review and will be replaced before any public release.
''';
