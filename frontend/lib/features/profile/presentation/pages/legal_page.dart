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
ShopXY is a Data Fiduciary under India's Digital Personal Data Protection Act, 2023 (DPDP). This notice explains what we collect, why, and the rights you have over your data.

What we hold
We store the minimum data needed to run your shop: account credentials, your product/vendor/party records, invoices and payments you create, notification preferences, and consent timestamps. We do not sell your data and do not share it with third parties except as required to operate the service (hosting, error monitoring) or by Indian law.

Data localisation
Your data is stored on servers located in India in line with applicable RBI / sector guidance. Backups are encrypted and held in the same jurisdiction.

Retention
Financial records — invoices, payments and supporting ledgers — are retained for at least 8 financial years to comply with the Companies Act, 2013 (§128) and the GST Act (§36). Other personal data is retained only as long as your account is active or as required to provide the service.

Your rights (DPDP §11 and §12)
You have the right to (a) access a copy of your personal data, (b) correct or update it, (c) withdraw consent and request erasure, and (d) nominate someone to act on your behalf. The Settings > Danger zone screen exposes "Export my data" (a downloadable JSON of every row tied to your account) and "Delete account" (immediate erasure for customer accounts; controlled erasure for shop-owner accounts whose books are still inside the 8-year retention window).

Consent withdrawal
You may withdraw consent at any time by deleting your account or by emailing support@shopxy.example. Withdrawal does not apply retroactively to processing performed lawfully before withdrawal.

Grievance redressal
DPDP §13 requires a published grievance contact. Please reach our Grievance Officer at support@shopxy.example. We aim to acknowledge within 7 days and respond substantively within 30 days. If unresolved, you may approach the Data Protection Board of India.
''';

const String _termsBody = '''
ShopXY is provided as-is for managing your shop's inventory, invoices, payments and customer relationships. By creating an account you agree to the terms below.

1. Account integrity. Provide accurate information when registering and keep your password confidential — you are responsible for all activity under your account.

2. Lawful use. Use the service only for legitimate business operations. No spam, no scraping, no attempts to compromise other accounts or to bypass billing.

3. Compliance with Indian law. You will comply with all applicable tax, GST and commerce laws of India. ShopXY assists with documentation but does not constitute legal or tax advice.

4. Data and consent. Your use of ShopXY is also governed by the Privacy Policy, which describes how we handle personal data under the DPDP Act, 2023 — including data localisation in India, an 8-year retention window for financial books (Companies Act §128 / GST §36), and your rights to access and delete your data via the in-app Settings screen.

5. Service availability. We may schedule maintenance or update features. We will give reasonable notice for material changes.

6. Termination. We may suspend accounts that violate these terms or that we reasonably suspect of fraudulent activity. You may close your account at any time via Settings > Delete account.

7. Grievances. Questions, complaints or DPDP requests can be sent to support@shopxy.example. The Grievance Officer responds within 30 days.
''';
