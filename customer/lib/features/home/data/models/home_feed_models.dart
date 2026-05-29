import 'package:flutter/material.dart';

/// Presentation models for the home feed.
///
/// These used to ship with hardcoded fixtures (the file name still
/// reflects that history). The fixtures have been replaced by API data
/// loaded through `HomeFeedProvider`; the classes below now describe
/// the *shape* widgets render, and the provider populates each list
/// from the `/home/feed` (+ `/me/home/personalized`) response.
///
/// Image fields carry server-relative paths or absolute URLs. Widgets
/// pass them through `resolveImageUrl(...)` before handing them to
/// `NetworkImageBox`. The legacy `imageId` field (an Unsplash photo id)
/// is gone — anything the backend returns has a real `imageUrl`.

/// Visual layout the merchant picked when authoring the slide. The
/// renderer in home_hero_carousel branches on this — older banners
/// without a template default to `classic` for backward compatibility.
enum HeroSlideTemplate {
  /// Image right, gradient overlay, brand chip + title + subtitle +
  /// shop-now button on the left. The original look.
  classic,

  /// Centered editorial: tiny accent eyebrow, large title, small "Explore"
  /// arrow, circular image medallion on the right. Soft tinted panel.
  minimal,

  /// Full-bleed image. No eyebrow / title / subtitle / button — the
  /// merchant supplies a ready-made banner with their own typography
  /// baked in. We just render the picture + the "AD" badge.
  imageOnly,

  /// Clean 50/50 split — solid bg-color panel on the left holds text +
  /// CTA, the image fills the right half with no gradient overlay.
  split,

  /// Full-bleed image with a dark scrim. Centered title + subtitle +
  /// CTA in white. Great for dramatic product photography.
  overlay,

  /// Promo-style. Big accent "% OFF" badge in the corner, product image
  /// hero. eyebrow becomes the deal label (e.g. "30% OFF").
  deal,

  /// Image fills the top, solid bottom panel (bgColor) holds the
  /// title/subtitle. Like a movie poster.
  poster;

  static HeroSlideTemplate fromWire(String? v) {
    switch (v) {
      case 'MINIMAL':
        return HeroSlideTemplate.minimal;
      case 'IMAGE_ONLY':
        return HeroSlideTemplate.imageOnly;
      case 'SPLIT':
        return HeroSlideTemplate.split;
      case 'OVERLAY':
        return HeroSlideTemplate.overlay;
      case 'DEAL':
        return HeroSlideTemplate.deal;
      case 'POSTER':
        return HeroSlideTemplate.poster;
      case 'CLASSIC':
      default:
        return HeroSlideTemplate.classic;
    }
  }

  String get wire {
    switch (this) {
      case HeroSlideTemplate.classic:
        return 'CLASSIC';
      case HeroSlideTemplate.minimal:
        return 'MINIMAL';
      case HeroSlideTemplate.imageOnly:
        return 'IMAGE_ONLY';
      case HeroSlideTemplate.split:
        return 'SPLIT';
      case HeroSlideTemplate.overlay:
        return 'OVERLAY';
      case HeroSlideTemplate.deal:
        return 'DEAL';
      case HeroSlideTemplate.poster:
        return 'POSTER';
    }
  }
}

/// How the slide's image fills its slot. Maps to BoxFit on the
/// renderer — COVER (default) crops to fill, CONTAIN letterboxes.
enum HeroImageFit {
  cover,
  contain;

  static HeroImageFit fromWire(String? v) {
    if (v == 'CONTAIN') return HeroImageFit.contain;
    return HeroImageFit.cover;
  }

  BoxFit get boxFit =>
      this == HeroImageFit.contain ? BoxFit.contain : BoxFit.cover;
}

class HeroSlide {
  const HeroSlide({
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.bgColor,
    required this.accent,
    this.template = HeroSlideTemplate.classic,
    this.imageFit = HeroImageFit.cover,
    this.brandImageUrl,
    this.brandImageFit = HeroImageFit.cover,
    this.ctaText,
    this.ctaTarget,
    this.eyebrow,
    this.bannerId,
  });

  final String brand;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Color bgColor;
  final Color accent;
  final HeroSlideTemplate template;
  final HeroImageFit imageFit;
  /// Optional shop logo. Empty/null falls back to the text brand chip.
  final String? brandImageUrl;
  final HeroImageFit brandImageFit;
  /// Merchant-supplied button label. Templates that render a CTA fall
  /// back to "Shop now" when this is null or empty.
  final String? ctaText;
  final String? ctaTarget;
  /// Tiny tagline above the title. Separate from `brand` so a slide can
  /// display both at once instead of one clobbering the other.
  final String? eyebrow;

  /// Server-side Banner id. Present when the slide came from the
  /// /home/feed payload; null for any locally-seeded fallback slides.
  /// Tapping a card with a bannerId opens the slide-detail page that
  /// renders the merchant's curated product list with per-row discounts.
  final int? bannerId;
}

class CategoryPuck {
  const CategoryPuck({
    required this.categoryId,
    required this.slug,
    required this.label,
    required this.imageUrl,
    required this.tint,
  });
  final int categoryId;
  final String slug;
  final String label;

  /// Server-relative or absolute. Null when the backend hasn't given
  /// the category an image yet — the puck falls back to its tint plus
  /// the first letter of the label.
  final String? imageUrl;
  final Color tint;
}

class FlashDealProduct {
  const FlashDealProduct({
    required this.productId,
    required this.saleId,
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.discountPct,
    required this.imageUrl,
    required this.soldPct,
    required this.endAt,
  });

  final int productId;
  final int saleId;
  final String name;
  final String price;
  final String originalPrice;
  final int discountPct;
  final String imageUrl;
  final double soldPct;
  final DateTime endAt;
}

class BrandSpotlight {
  const BrandSpotlight({
    required this.spotlightId,
    required this.brand,
    required this.subtitle,
    required this.dealLabel,
    required this.imageUrl,
    required this.bgColor,
    this.ctaTarget,
    this.shopSlug,
  });

  final int spotlightId;
  final String brand;
  final String subtitle;
  final String dealLabel;
  final String imageUrl;
  final Color bgColor;
  final String? ctaTarget;

  /// Slug of the shop being spotlighted — lets the brand-card tap open
  /// the customer ShopProfilePage without re-parsing the CTA target.
  final String? shopSlug;
}

class ProductCard {
  const ProductCard({
    required this.productId,
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.bankPrice,
    required this.rating,
    required this.ratingCount,
    required this.ratingCountRaw,
    required this.imageUrl,
    required this.bgColor,
    this.tag,
    this.isAd = false,
    this.promotionId,
    this.shopSlug,
    this.brand,
    this.discountPct = 0,
    this.freeDelivery = true,
  });

  final int productId;
  final String name;
  final String price;
  final String originalPrice;
  final String bankPrice;
  final double rating;
  /// Pretty-printed count for the chip ("1.2k", "37"). Kept separate
  /// from [ratingCountRaw] so the badge formatting doesn't lose the
  /// underlying integer the trust-mark logic needs.
  final String ratingCount;
  final int ratingCountRaw;
  final String imageUrl;
  final Color bgColor;
  final String? tag;
  final bool isAd;
  /// Set when the card came from a sponsored slot — the customer
  /// renders an "AD" chip and the impression event attributes back
  /// to this promotion for billing.
  final int? promotionId;
  /// Slug of the shop owning this product — lets the PDP and any
  /// inline "Visit shop" link route without a second API call.
  final String? shopSlug;
  /// Free-text brand name surfaced on the PDP and used by the home
  /// `BrandFocusBlock` to cluster products from the same manufacturer.
  /// Nullable because some catalog entries don't have a brand set.
  final String? brand;

  /// Integer percent-off, computed from mrp vs sellingPrice. 0 means
  /// "show no discount chip" (either the prices match or the product
  /// has no MRP set). Capped at 99 in the mapper so the chip stays
  /// two-digit-clean.
  final int discountPct;

  /// Hint that this product qualifies for free delivery — drives the
  /// "FREE Delivery" trust line under the price. True for now until a
  /// per-shop / per-pincode shipping rule exists; flipping the default
  /// later is the only change needed downstream.
  final bool freeDelivery;

  /// "Assured" / verified-seller-style trust mark eligibility. Cards
  /// with both a strong rating count and a non-trivial average get
  /// the badge — mirrors the heuristic Flipkart's "Assured" chip uses.
  bool get isAssured => ratingCountRaw >= 50 && rating >= 4.0;
}

class CategoryTab {
  const CategoryTab(this.label);
  final String label;
}

class CollectionTile {
  const CollectionTile({
    required this.collectionId,
    required this.slug,
    required this.label,
    required this.imageUrl,
  });
  final int collectionId;
  final String slug;
  final String label;
  final String imageUrl;
}

/// Static UI scaffolding — these aren't backed by API endpoints.
/// Category tabs and the trust strip are part of the design, not the
/// catalogue, so they live here as constants rather than chasing a
/// network round-trip for every cold start.
class HomeStaticData {
  HomeStaticData._();

  static const List<String> searchHints = [
    'Search "noise cancelling earbuds"',
    'Search "summer kurta sets"',
    'Search "running shoes for men"',
    'Search "iphone 17 pro"',
    'Search "skincare serums"',
  ];

  static const List<CategoryTab> categoryTabs = [
    CategoryTab('For You'),
    CategoryTab('Fashion'),
    CategoryTab('Mobiles'),
    CategoryTab('Beauty'),
    CategoryTab('Electronics'),
    CategoryTab('Home'),
    CategoryTab('Appliances'),
    CategoryTab('Grocery'),
    CategoryTab('Travel'),
  ];

}
