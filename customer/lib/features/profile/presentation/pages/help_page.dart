import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

const _supportEmail = 'support@shopxy.app';

class HelpAndFaqPage extends StatelessWidget {
  const HelpAndFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'Help & FAQ'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.huge),
        children: [
          _ContactCard(
            onCopy: () async {
              await Clipboard.setData(
                  const ClipboardData(text: _supportEmail));
              if (context.mounted) {
                showAppSnackbar(
                  context,
                  message: 'Support email copied',
                  tone: AppSnackbarTone.success,
                );
              }
            },
          ),
          const SizedBox(height: AppSizes.xl),
          const _SectionTitle(label: 'Orders & delivery'),
          const _FaqTile(
            question: 'Where is my order?',
            answer:
                'Open Orders from the bottom nav. Each order shows its '
                'current stage — Pending, Confirmed, Dispatched, '
                'Delivered. Tap into an order to see the per-shop status '
                'when an order has items from multiple sellers.',
          ),
          const _FaqTile(
            question: "Can I change my delivery address after ordering?",
            answer:
                'Address is captured at checkout and snapshotted onto '
                'the order. To change it after placing the order, '
                'contact the seller via the order detail page or email '
                'support — we\'ll relay the request.',
          ),
          const _FaqTile(
            question: 'My order is delayed. What do I do?',
            answer:
                "If a delivery is more than 3 days past the seller's "
                "estimated window, open the order and tap 'Need help' "
                "or email $_supportEmail with the order number.",
          ),
          const SizedBox(height: AppSizes.lg),
          const _SectionTitle(label: 'Returns & refunds'),
          const _FaqTile(
            question: 'How do I return an item?',
            answer:
                'Open the delivered order, tap "Request return", pick '
                'the item(s) and reason. Sellers approve, then the item '
                'is picked up or you ship it back per the seller\'s '
                'return policy.',
          ),
          const _FaqTile(
            question: "Why was my return rejected?",
            answer:
                "Each shop sets its own return policy — visible on the "
                "shop's page and on the PDP under 'Policies'. Common "
                "reasons: outside the return window, item used or "
                "damaged, or product is on the shop's exclusion list "
                "(e.g. innerwear, food).",
          ),
          const _FaqTile(
            question: 'When will I get my refund?',
            answer:
                'Most refunds land in your wallet as soon as the seller '
                'marks the return REFUNDED. From the wallet you can use '
                'the balance on your next order. Refunds to the original '
                'payment method (when offered by the seller) take 3–7 '
                'business days.',
          ),
          const SizedBox(height: AppSizes.lg),
          const _SectionTitle(label: 'Account & privacy'),
          const _FaqTile(
            question: 'How do I change my email or phone?',
            answer:
                "Phone is editable on Profile → Edit profile. Email "
                "changes aren't self-service yet — email "
                "$_supportEmail and we'll update it after verifying "
                "you control both addresses.",
          ),
          const _FaqTile(
            question: 'How do I delete my account?',
            answer:
                "Email $_supportEmail from the address on file. We'll "
                "erase your account and personal data within 30 days "
                "per DPDP §11 (right to erasure). Confirmed invoices "
                "are retained for 8 years per GST law, with personal "
                "identifiers anonymised.",
          ),
          const _FaqTile(
            question: 'How do I see what data Shopxy stores about me?',
            answer:
                'Email $_supportEmail with the subject "Data export" '
                'from the address on file. We send the JSON dump within '
                '30 days per DPDP §11.',
          ),
          const SizedBox(height: AppSizes.lg),
          const _SectionTitle(label: 'Payments & coupons'),
          const _FaqTile(
            question: 'My coupon code isn\'t working.',
            answer:
                'Check the minimum order, validity window, and per-user '
                'limit on the coupon card. Some coupons are first-order '
                'only; others auto-apply at checkout so you never need '
                'to type the code.',
          ),
          const _FaqTile(
            question: 'Bank offers — do I need a code?',
            answer:
                'No. Bank offers are platform-wide and apply '
                'automatically at the payment step when you pay with the '
                'eligible card. The PDP "Offers" strip shows offers '
                'eligible for the item\'s price.',
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.onCopy});
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.brandSoft,
      shape: AppShapes.squircle(AppSizes.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent_rounded,
                    color: AppColors.brandStrong),
                const SizedBox(width: AppSizes.sm),
                Text(
                  'Talk to us',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'Email us with your order number and we\'ll get back to '
              'you within one business day.',
              style: TextStyle(color: AppColors.black, fontSize: 13),
            ),
            const SizedBox(height: AppSizes.md),
            Material(
              color: AppColors.white,
              shape: AppShapes.squircle(AppSizes.radiusSm),
              child: InkWell(
                customBorder: AppShapes.squircle(AppSizes.radiusSm),
                onTap: onCopy,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md, vertical: AppSizes.sm),
                  child: Row(
                    children: const [
                      Icon(Icons.email_outlined,
                          size: 16, color: AppColors.brandStrong),
                      SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          _supportEmail,
                          style: TextStyle(
                            color: AppColors.brandStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.copy_rounded,
                          size: 16, color: AppColors.brandStrong),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.sm),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: Theme(
          // Strip the default divider Material adds above expansion
          // tiles so the squircle border stays crisp.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(
                AppSizes.md, 0, AppSizes.md, AppSizes.md),
            iconColor: AppColors.muted,
            collapsedIconColor: AppColors.muted,
            title: Text(
              question,
              style: const TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  answer,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
