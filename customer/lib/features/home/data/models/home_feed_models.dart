import 'package:flutter/material.dart';

class HeroSlide {
  const HeroSlide({
    required this.id,
    required this.imageUrl,
    this.linkUrl,
    this.productCount = 0,
  });

  final String id;

  final String imageUrl;

  final String? linkUrl;

  final int productCount;
}

class CategoryPuck {
  const CategoryPuck({
    required this.categoryId,
    required this.slug,
    required this.label,
    required this.imageUrl,
    required this.tint,
  });
  final String categoryId;
  final String slug;
  final String label;

  final String? imageUrl;
  final Color tint;
}

class ProductCard {
  const ProductCard({
    required this.productId,
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.rating,
    required this.ratingCount,
    required this.ratingCountRaw,
    required this.imageUrl,
    required this.bgColor,
    this.tag,
    this.shopSlug,
    this.brand,
    this.discountPct = 0,
    this.freeDelivery = false,
  });

  final String productId;
  final String name;
  final String price;
  final String originalPrice;
  final double rating;
  final String ratingCount;
  final int ratingCountRaw;
  final String imageUrl;
  final Color bgColor;
  final String? tag;
  final String? shopSlug;
  final String? brand;

  final int discountPct;

  final bool freeDelivery;

  bool get isAssured => ratingCountRaw >= 50 && rating >= 4.0;
}

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
