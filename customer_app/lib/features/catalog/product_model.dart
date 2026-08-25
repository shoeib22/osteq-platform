import 'category_model.dart';

class ProductVariant {
  final String id;
  final String sku;
  final Map<String, dynamic> attributes;
  final int stockQuantity;
  final double priceInRupees;
  final String tier;

  ProductVariant({
    required this.id,
    required this.sku,
    required this.attributes,
    required this.stockQuantity,
    required this.priceInRupees,
    required this.tier,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      sku: json['sku'] as String,
      attributes: Map<String, dynamic>.from(json['attributes'] as Map),
      stockQuantity: json['stockQuantity'] as int,
      priceInRupees: (json['priceInRupees'] as num).toDouble(),
      tier: json['tier'] as String,
    );
  }

  String get attributesLabel => attributes.values.map((v) => v.toString()).join(' / ');
}

class Product {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final Map<String, dynamic>? specs;
  final List<String> images;
  final Category category;
  final List<ProductVariant> variants;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.specs,
    required this.images,
    required this.category,
    required this.variants,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      specs: json['specs'] == null ? null : Map<String, dynamic>.from(json['specs'] as Map),
      images: (json['images'] as List).map((e) => e as String).toList(),
      category: Category.fromJson(json['category'] as Map<String, dynamic>),
      variants: (json['variants'] as List)
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  double get lowestPriceInRupees =>
      variants.map((v) => v.priceInRupees).reduce((a, b) => a < b ? a : b);
}
