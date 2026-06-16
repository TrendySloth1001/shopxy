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
/// `NetworkImageBox`.

/// A banner placement. The backend now returns banners as plain
/// tappable images — just an id, the image to render, and an optional
/// link to follow on tap. The merchant-authored template/colour/CTA
/// system is gone; a banner is JUST a picture + an optional link.
class HeroSlide {
  const HeroSlide({
    required this.id,
    required this.imageUrl,
    this.linkUrl,
  });

  final int id;

  /// Server-relative or absolute. Rendered through `NetworkImageBox`.
  final String imageUrl;

  /// Optional tap target. Absolute URLs / app-route hints come straight
  /// from the merchant; null means the banner is decorative (no tap).
  final String? linkUrl;
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
  /// Legacy sponsored-slot flag. The backend no longer returns ad rows
  /// in the home feed, so this stays false in practice — kept only so
  /// the product carousel's optional "AD" chip path still compiles.
  final bool isAd;
  /// Slug of the shop owning this product — lets the PDP and any
  /// inline "Visit shop" link route without a second API call.
  final String? shopSlug;
  /// Free-text brand name surfaced on the PDP. Nullable because some
  /// catalog entries don't have a brand set.
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

/// Static UI scaffolding — these aren't backed by API endpoints.
/// The trust strip and the rotating search hints are part of the
/// design, not the catalogue, so they live here as constants rather
/// than chasing a network round-trip for every cold start.
class HomeStaticData {
  HomeStaticData._();

  static const List<String> searchHints = [
    'Search "noise cancelling earbuds"',
    'Search "summer kurta sets"',
    'Search "running shoes for men"',
    'Search "iphone 17 pro"',
    'Search "skincare serums"',
  ];
}
