import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: AppStrings.about,
      sections: [
        _Section(
          title: 'Shopxy',
          body:
              'Shopxy connects you to your neighbourhood shops. Browse what they stock, place orders, and keep every invoice in one place.\n\n'
              'Version 1.0.0',
        ),
        _Section(
          title: 'Need help?',
          body:
              'Reach us at support@shopxy.app. Include your order number so we can pull it up quickly.',
        ),
      ],
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: AppStrings.privacyPolicy,
      sections: [
        _Section(
          title: 'What we collect',
          body:
              'Your name, email, phone, and delivery addresses you add — used to fulfil the orders you place and to keep your account secure. We also log basic technical data (device, app version, error logs) to keep the service working.',
        ),
        _Section(
          title: 'How we use it',
          body:
              'Only to operate the app: order routing, invoice ledgers, support, and fraud prevention. We do not sell personal data, and we do not use it for targeted advertising to children.',
        ),
        _Section(
          title: 'Who we share it with',
          body:
              'The shops you order from see the order itself, the snapshotted name/phone/address on that order, and the items you bought. Beyond that we share data only with the processors that run ShopXY:\n\n'
              '• Razorpay — payment collection, refunds and payouts. Payment/KYC details you submit are handled by Razorpay and not stored by us.\n'
              '• Cloud hosting & infrastructure — app hosting, database, storage and backups. [TO FILL: name the hosting provider]',
        ),
        _Section(
          title: 'Retention schedule',
          body:
              'Invoices, orders and payment records: 8 years (Indian tax/company law). Account profile and addresses: while your account is active, then deleted or anonymised within 90 days of account deletion except records we must legally keep. Support/grievance records: up to 3 years. Technical/security logs: up to 180 days.',
        ),
        _Section(
          title: 'Your rights (DPDP Act, 2023)',
          body:
              'You can access, correct, export or delete your personal data, withdraw consent, and nominate someone to act for you. Export and deletion are honoured by our systems. Edit your profile from Profile → Edit profile and delivery addresses from Profile → Addresses; for an account export or deletion from this app, email support@shopxy.app from the address on file (see Help → Account & privacy) or contact our Grievance Officer below. [TO FILL: wire in-app self-service export/delete (DELETE /auth/me, export endpoint) and point here once shipped]',
        ),
        _Section(
          title: 'Children\'s data',
          body:
              'ShopXY is intended for users aged 18 and over. We do not knowingly process a child\'s personal data without verifiable parental or guardian consent, and we do not track, monitor, or target advertising at children. If we learn we hold a child\'s data without the required consent, we delete it.',
        ),
        _Section(
          title: 'Cross-border transfers',
          body:
              'Your data is primarily stored and processed on infrastructure in India. Where a processor (such as a payment provider) operates outside India, any transfer is limited to that purpose and made only to countries not restricted by the Government of India, with contractual safeguards.',
        ),
        _Section(
          title: 'Security & breach notification',
          body:
              'We protect data with encryption in transit and access controls, and forward payment data to our payment provider rather than storing it. In the event of a personal-data breach we will notify the Data Protection Board of India and affected users without undue delay, within the timelines prescribed under the DPDP Act and its rules.',
        ),
        _grievanceSection,
        _Section(
          title: 'Contact',
          body: 'For privacy questions, email privacy@shopxy.app.',
        ),
      ],
    );
  }
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoScaffold(
      title: AppStrings.termsOfService,
      sections: [
        _Section(
          title: 'Using Shopxy',
          body:
              'You agree to use the app for your own personal shopping. Don\'t abuse the order, cancel, or messaging systems.',
        ),
        _Section(
          title: 'Orders & payments',
          body:
              'Orders are accepted by individual shops, not by Shopxy. Pricing, availability, and fulfilment are the shop\'s responsibility.',
        ),
        _Section(
          title: 'Account',
          body:
              'You\'re responsible for keeping your password safe. Notify us at support@shopxy.app if you suspect unauthorised access.',
        ),
        _Section(
          title: 'Liability',
          body:
              'Shopxy is provided "as is". We aim for high availability but don\'t guarantee uninterrupted service.',
        ),
        _grievanceSection,
      ],
    );
  }
}

const _Section _grievanceSection = _Section(
  title: 'Grievance Officer',
  body:
      'Under the Consumer Protection (E-Commerce) Rules 2020, the IT (Intermediary Guidelines) Rules 2021, and the DPDP Act 2023, you may contact our Grievance Officer:\n\n'
      'Name: [TO FILL: Grievance Officer name]\n'
      'Designation: [TO FILL: designation]\n'
      'Email: grievance@shopxy.app\n'
      'Phone: [TO FILL: phone number]\n'
      'Postal address: [TO FILL: registered postal address]\n\n'
      'We acknowledge every grievance within 48 hours and aim to resolve consumer grievances within one month. Grievances about your personal data under the DPDP Act are addressed within 15 days.',
);

class _InfoScaffold extends StatelessWidget {
  const _InfoScaffold({required this.title, required this.sections});
  final String title;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppAppBar(title: title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.huge,
        ),
        children: [
          for (final s in sections) ...[
            Text(
              s.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              s.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: AppSizes.xl),
          ],
        ],
      ),
    );
  }
}

class _Section {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;
}
