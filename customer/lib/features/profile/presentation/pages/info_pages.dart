import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';

/// Three near-identical static pages — About, Privacy, Terms — that
/// used to be `coming soon` snackbar stubs on the profile screen.
/// Content is intentionally short and editable in one place; the legal
/// team will tighten it before any real launch.
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
              'Your name, email, phone, and delivery addresses you add — used to fulfil the orders you place and to keep your account secure.',
        ),
        _Section(
          title: 'How we use it',
          body:
              'Only to operate the app: order routing, invoice ledgers, support, and fraud prevention. We do not sell personal data.',
        ),
        _Section(
          title: 'Who sees your data',
          body:
              'The shops you order from see the order itself, the snapshotted name/phone/address on that order, and the items you bought.',
        ),
        _Section(
          title: 'Your controls',
          body:
              'Edit or delete delivery addresses from Profile → Addresses. Account deletion: contact support@shopxy.app.',
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
      ],
    );
  }
}

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
