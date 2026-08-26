import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bottom_sheet.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/constants/app_curves.dart';

class TrustItem {
  const TrustItem({
    required this.icon,
    required this.label,
    required this.title,
    required this.detail,
  });
  final AppIconData icon;
  final String label;
  final String title;
  final String detail;
}

const List<TrustItem> kDefaultTrustItems = [
  TrustItem(
    icon: AppIcons.localShippingOutlined,
    label: 'Free delivery',
    title: 'Free delivery',
    detail:
        'Enjoy free delivery on eligible orders. Any delivery charge or minimum is always shown clearly before you pay.',
  ),
  TrustItem(
    icon: AppIcons.replayOutlined,
    label: '7-day returns',
    title: 'Easy 7-day returns',
    detail:
        'Changed your mind? Most items can be returned within 7 days of delivery. The exact window and refund method are shown on each order.',
  ),
  TrustItem(
    icon: AppIcons.verifiedOutlined,
    label: '100% authentic',
    title: '100% authentic',
    detail:
        'Every product comes from a verified shop on Shopxy. If something isn’t as described, report it from the order and we’ll step in.',
  ),
  TrustItem(
    icon: AppIcons.sellOutlined,
    label: 'Best prices',
    title: 'Great prices',
    detail:
        'Shops compete to give you a great deal, and any available offer is applied automatically at checkout.',
  ),
];

const Duration _kRotateInterval = Duration(seconds: 3);
const Duration _kSlideDuration = Duration(milliseconds: 420);

class HomeTrustStrip extends StatefulWidget {
  const HomeTrustStrip({super.key, this.items = kDefaultTrustItems});

  final List<TrustItem> items;

  @override
  State<HomeTrustStrip> createState() => _HomeTrustStripState();
}

class _HomeTrustStripState extends State<HomeTrustStrip>
    with WidgetsBindingObserver {
  final _controller = PageController(viewportFraction: 0.62);
  Timer? _timer;
  int _page = 0;
  bool _interacting = false;
  bool _reduceMotion = false;

  List<TrustItem> get _items => widget.items;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncTimer(resumed: state == AppLifecycleState.resumed);
  }

  void _syncTimer({bool resumed = true}) {
    final shouldRun = !_reduceMotion && resumed && _items.length > 1;
    if (shouldRun) {
      _timer ??= Timer.periodic(_kRotateInterval, (_) {
        if (!mounted || !_controller.hasClients || _interacting) return;
        _page++;
        _controller.animateToPage(
          _page,
          duration: _kSlideDuration,
          curve: AppCurves.standardEmphasized,
        );
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _open(int index) => showTrustPromisesSheet(context, _items, index);

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    if (_reduceMotion) {
      return _StaticTrustRow(items: _items, onTap: _open);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: SizedBox(
        height: 30,
        child: Listener(
          onPointerDown: (_) => _interacting = true,
          onPointerUp: (_) => _interacting = false,
          onPointerCancel: (_) => _interacting = false,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => _page = i,
            itemBuilder: (_, i) {
              final idx = i % _items.length;
              final cell = _TrustCell(
                item: _items[idx],
                onTap: () => _open(idx),
              );
              return AnimatedBuilder(
                animation: _controller,
                builder: (_, child) {
                  var delta = (i - _page).toDouble();
                  if (_controller.hasClients &&
                      _controller.position.haveDimensions) {
                    delta = i - (_controller.page ?? _page.toDouble());
                  }
                  final dist = delta.abs().clamp(0.0, 1.0);
                  return Opacity(
                    opacity: 1 - dist * 0.7,
                    child: Transform.scale(
                      scale: 1 - dist * 0.12,
                      child: child,
                    ),
                  );
                },
                child: cell,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrustCell extends StatelessWidget {
  const _TrustCell({required this.item, required this.onTap});
  final TrustItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(item.icon, color: AppColors.brandStrong, size: 16),
              const SizedBox(width: 6),
              Text(
                item.label,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticTrustRow extends StatelessWidget {
  const _StaticTrustRow({required this.items, required this.onTap});
  final List<TrustItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.xs,
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      items[i].icon,
                      color: AppColors.brandStrong,
                      size: 17,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      items[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void showTrustPromisesSheet(
  BuildContext context,
  List<TrustItem> items,
  int active,
) {
  showAppBottomSheet<void>(
    context,
    title: 'Why shop on Shopxy',
    builder: (ctx) => ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.lg,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (_, i) =>
          _PromiseRow(item: items[i], highlighted: i == active),
    ),
  );
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({required this.item, required this.highlighted});
  final TrustItem item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: highlighted ? AppColors.brandSoft : AppColors.canvas,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: highlighted
              ? const BorderSide(color: AppColors.brand, width: 1)
              : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppIcon(item.icon, color: AppColors.brandStrong, size: 20),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.detail,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.4,
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
