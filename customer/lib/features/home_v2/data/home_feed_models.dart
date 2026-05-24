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

class HeroSlide {
  const HeroSlide({
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.bgColor,
    required this.accent,
    this.ctaTarget,
    this.bannerId,
  });

  final String brand;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Color bgColor;
  final Color accent;
  final String? ctaTarget;

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

class TrustItem {
  const TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
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

class AdCard {
  const AdCard({
    required this.bannerId,
    required this.brand,
    required this.headline,
    required this.cta,
    required this.imageUrl,
    required this.bgColor,
    this.ctaTarget,
  });

  final int bannerId;
  final String brand;
  final String headline;
  final String cta;
  final String imageUrl;
  final Color bgColor;
  final String? ctaTarget;
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
    required this.imageUrl,
    required this.bgColor,
    this.tag,
    this.isAd = false,
    this.promotionId,
    this.shopSlug,
  });

  final int productId;
  final String name;
  final String price;
  final String originalPrice;
  final String bankPrice;
  final double rating;
  final String ratingCount;
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

class CuratedRailItem {
  const CuratedRailItem({
    this.collectionSlug,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.imageUrl,
    required this.bgColor,
    required this.accentColor,
    this.ctaTarget,
  });

  final String? collectionSlug;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String cta;
  final String imageUrl;
  final Color bgColor;
  final Color accentColor;
  final String? ctaTarget;
}

/// Static UI scaffolding — these aren't backed by API endpoints.
/// Category tabs and the trust strip are part of the design, not the
/// catalogue, so they live here as constants rather than chasing a
/// network round-trip for every cold start.
class HomeV2StaticData {
  HomeV2StaticData._();

  static const String defaultLocation = 'Deliver to: New Delhi 110001';

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

  static const List<TrustItem> trustItems = [
    TrustItem(icon: Icons.local_shipping_outlined, label: 'Free delivery'),
    TrustItem(icon: Icons.replay_outlined, label: '7-day returns'),
    TrustItem(icon: Icons.verified_outlined, label: '100% authentic'),
    TrustItem(icon: Icons.savings_outlined, label: 'Lowest prices'),
  ];
}
