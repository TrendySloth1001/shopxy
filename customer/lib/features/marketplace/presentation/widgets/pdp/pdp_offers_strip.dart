import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Horizontal carousel mixing two sources of offer cards:
///
/// 1. Platform-curated **bank offers** — central admin-managed
///    tie-ups (HDFC / ICICI / SBI / Axis / Kotak / Amex / YES / HSBC /
///    SC / IDFC / BoB / RBL). Each renders with a brand-coloured
///    monogram tile. The headline is composed client-side from the
///    structured row (`discountValue`, `cardType`, `maxDiscount`) so
///    there's no chance the on-wire text drifts away from the
///    discount the bank actually agreed to fund.
///
/// 2. Per-product **coupon / EMI / exchange** offers entered by the
///    merchant in their product editor. These render with a clean
///    material icon in a tinted tile. BANK-kind entries from this
///    source are intentionally filtered out — they're legacy data
///    from before the platform-bank-offer split.
class PdpOffersStrip extends StatelessWidget {
  const PdpOffersStrip({
    super.key,
    required this.offers,
    this.bankOffers = const [],
  });
  final List<ProductOffer> offers;
  final List<PlatformBankOffer> bankOffers;

  @override
  Widget build(BuildContext context) {
    // Per-product BANK entries are dropped — bank surface is now
    // platform-scope. Legacy products may still have rows with
    // `kind == 'BANK'` until they're re-saved.
    final productOffers =
        offers.where((o) => o.kind != 'BANK').toList(growable: false);
    if (productOffers.isEmpty && bankOffers.isEmpty) {
      return const SizedBox.shrink();
    }
    final totalCount = productOffers.length + bankOffers.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSizes.sm, 0, AppSizes.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text('Offers',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.black)),
          ),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              itemCount: totalCount,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
              itemBuilder: (_, i) {
                // Platform bank offers lead the strip — they're the
                // biggest visible perk and brand recognition makes
                // them the strongest "scan-and-trust" tile.
                if (i < bankOffers.length) {
                  return _BankOfferCard(offer: bankOffers[i]);
                }
                return _OfferCard(offer: productOffers[i - bankOffers.length]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BankOfferCard extends StatelessWidget {
  const _BankOfferCard({required this.offer});
  final PlatformBankOffer offer;

  @override
  Widget build(BuildContext context) {
    final bank = _bankByCode(offer.bank);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: ShapeDecoration(
        color: AppColors.infoSoft,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bank != null
              ? _BankMonogram(bank: bank)
              : Container(
                  width: 36,
                  height: 36,
                  decoration: ShapeDecoration(
                    color: AppColors.white,
                    shape: AppShapes.squircle(AppSizes.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.account_balance_outlined,
                      size: 18, color: AppColors.info),
                ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bank?.shortName ?? 'BANK OFFER',
                  style: TextStyle(
                    color: bank?.color ?? AppColors.info,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  offer.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (offer.terms != null && offer.terms!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      offer.terms!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
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

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});
  final ProductOffer offer;

  ({Color bg, Color fg, IconData icon, String label}) _kindMeta() {
    switch (offer.kind) {
      case 'EMI':
        return (
          bg: AppColors.brandSoft,
          fg: AppColors.brandStrong,
          icon: Icons.calendar_month_rounded,
          label: 'NO-COST EMI',
        );
      case 'EXCHANGE':
        return (
          bg: AppColors.accentRoseSoft,
          fg: AppColors.accentRose,
          icon: Icons.swap_horiz_rounded,
          label: 'EXCHANGE',
        );
      case 'COUPON':
      default:
        return (
          bg: AppColors.warningSoft,
          fg: AppColors.warning,
          icon: Icons.local_offer_outlined,
          label: 'COUPON',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _kindMeta();
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: ShapeDecoration(
        color: meta.bg,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(meta.icon, size: 18, color: meta.fg),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.label,
                  style: TextStyle(
                    color: meta.fg,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  offer.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (offer.detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      offer.detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
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

/// Detected bank — pairs a brand colour with a recognisable monogram
/// and short-name caption. Kept in this file (not the theme) because
/// these are vendor brand colours, not theme tokens.
class _Bank {
  const _Bank({
    required this.shortName,
    required this.monogram,
    required this.color,
  });
  final String shortName;
  final String monogram;
  final Color color;
}

const _hdfc = _Bank(
  shortName: 'HDFC BANK',
  monogram: 'H',
  color: Color(0xFF004C8F),
);
const _icici = _Bank(
  shortName: 'ICICI BANK',
  monogram: 'I',
  color: Color(0xFFB02A30),
);
const _sbi = _Bank(
  shortName: 'STATE BANK OF INDIA',
  monogram: 'S',
  color: Color(0xFF22409A),
);
const _axis = _Bank(
  shortName: 'AXIS BANK',
  monogram: 'A',
  color: Color(0xFF97144D),
);
const _kotak = _Bank(
  shortName: 'KOTAK MAHINDRA',
  monogram: 'K',
  color: Color(0xFFEF3E42),
);
const _amex = _Bank(
  shortName: 'AMERICAN EXPRESS',
  monogram: 'AX',
  color: Color(0xFF016FD0),
);
const _yes = _Bank(
  shortName: 'YES BANK',
  monogram: 'Y',
  color: Color(0xFF00518F),
);
const _hsbc = _Bank(
  shortName: 'HSBC',
  monogram: 'H',
  color: Color(0xFFD90A1A),
);
const _sc = _Bank(
  shortName: 'STANDARD CHARTERED',
  monogram: 'SC',
  color: Color(0xFF0F8C5C),
);
const _idfc = _Bank(
  shortName: 'IDFC FIRST',
  monogram: 'F',
  color: Color(0xFF931E2C),
);
const _bob = _Bank(
  shortName: 'BANK OF BARODA',
  monogram: 'B',
  color: Color(0xFFE57100),
);
const _rbl = _Bank(
  shortName: 'RBL BANK',
  monogram: 'R',
  color: Color(0xFFBD202E),
);

/// Lookup by the platform-bank-offer's structured short code. Returns
/// null when we don't recognise the bank — the card falls back to a
/// generic "BANK OFFER" tile rather than crashing on a typo.
_Bank? _bankByCode(String code) {
  switch (code) {
    case 'HDFC':
      return _hdfc;
    case 'ICICI':
      return _icici;
    case 'SBI':
      return _sbi;
    case 'AXIS':
      return _axis;
    case 'KOTAK':
      return _kotak;
    case 'AMEX':
      return _amex;
    case 'YES':
      return _yes;
    case 'HSBC':
      return _hsbc;
    case 'SC':
      return _sc;
    case 'IDFC':
      return _idfc;
    case 'BOB':
      return _bob;
    case 'RBL':
      return _rbl;
    default:
      return null;
  }
}

class _BankMonogram extends StatelessWidget {
  const _BankMonogram({required this.bank});
  final _Bank bank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: ShapeDecoration(
        color: bank.color,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      alignment: Alignment.center,
      child: Text(
        bank.monogram,
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w900,
          fontSize: bank.monogram.length > 1 ? 13 : 16,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
