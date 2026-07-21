import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/pages/login_page.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_pill_button.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

/// One onboarding slide's content.
class _Slide {
  const _Slide({
    required this.imageUrl,
    required this.eyebrow,
    required this.title,
    required this.body,
  });
  final String imageUrl;
  final String eyebrow;
  final String title;
  final String body;
}

/// First-run onboarding — immersive, full-bleed photo slides with the
/// copy and controls overlaid on a dark scrim. Shopper-first framing
/// (discover → delivery → deals). "Get started" drops into the
/// guest-browsable shell; "Sign in" completes onboarding then opens
/// login. Gated by [OnboardingController] so it shows once.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  // Lifestyle/shopping photos via the shared Unsplash helper — swap the
  // IDs for branded artwork when ready. NetworkImageBox handles
  // load/error/timeout.
  static final List<_Slide> _slides = [
    _Slide(
      imageUrl: HomeImg.unsplash('1483985988355-763728e1935b', w: 1000, h: 1400),
      eyebrow: 'WELCOME TO SHOPXY',
      title: 'Shop everything\nyou love',
      body:
          'Thousands of products from local shops and the brands you know — discovered in one place.',
    ),
    _Slide(
      imageUrl: HomeImg.unsplash('1607082348824-0a96f2a4b9da', w: 1000, h: 1400),
      eyebrow: 'FAST, TRACKED DELIVERY',
      title: 'From cart to\nyour doorstep',
      body:
          'Order in seconds, follow every step from packed to delivered, and pay securely in the app.',
    ),
    _Slide(
      imageUrl: HomeImg.unsplash('1556742049-0cfed4f6a45d', w: 1000, h: 1400),
      eyebrow: 'DEALS MADE FOR YOU',
      title: 'Save more on\nevery order',
      body:
          'Save your favourites, unlock member-only offers, and never miss a price drop.',
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => context.read<OnboardingController>().complete();

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: AppDurations.long,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _signIn() async {
    // Capture the root navigator before completing — `complete()` swaps
    // the root view to the shell and unmounts this page.
    final nav = Navigator.of(context, rootNavigator: true);
    await context.read<OnboardingController>().complete();
    nav.push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Swiping changes the full-bleed photo + its copy.
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ImmersiveSlide(slide: _slides[i]),
          ),
          // Fixed controls that don't swipe with the pages.
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    opacity: _isLast ? 0 : 1,
                    duration: AppDurations.short,
                    child: TextButton(
                      onPressed: _isLast ? null : _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg, vertical: AppSizes.sm),
                        textStyle: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSizes.xl, 0, AppSizes.xl, AppSizes.lg),
                  child: Column(
                    children: [
                      _Dots(count: _slides.length, index: _index),
                      const SizedBox(height: AppSizes.xl),
                      AppPillButton(
                        label: _isLast ? 'Get started' : 'Continue',
                        icon: _isLast ? null : AppIcons.arrowForwardRounded,
                        color: AppColors.brand,
                        onPressed: _next,
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      AppColors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          TextButton(
                            onPressed: _signIn,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.white,
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            child: const Text('Sign in'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveSlide extends StatelessWidget {
  const _ImmersiveSlide({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NetworkImageBox(url: slide.imageUrl, fit: BoxFit.cover),
        // Scrim: a touch at the top (for the Skip button) and a heavy
        // bottom so the copy + controls stay legible on any photo.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.black.withValues(alpha: 0.4),
                Colors.transparent,
                Colors.transparent,
                AppColors.black.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.18, 0.42, 0.92],
            ),
          ),
        ),
        // Copy sits above the fixed controls (which occupy ~210px).
        Positioned(
          left: AppSizes.xl,
          right: AppSizes.xl,
          bottom: 210,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide.eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.brandSoft,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                slide.title,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.6,
                    ),
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                slide.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Animated page indicator — the active dot stretches into a pill.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: AppDurations.medium,
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
          width: active ? AppSizes.xxl : AppSizes.sm,
          height: AppSizes.sm,
          decoration: BoxDecoration(
            color: active
                ? AppColors.brand
                : AppColors.white.withValues(alpha: 0.38),
            borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
          ),
        );
      }),
    );
  }
}
