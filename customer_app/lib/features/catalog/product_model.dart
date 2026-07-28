import 'category_model.dart';

class ProductVariant {
  final String id;
  final String sku;
  final Map<String, dynamic> attributes;
  final int stockQuantity;
  final int priceInPaise;
  final String tier;

  ProductVariant({
    required this.id,
    required this.sku,
    required this.attributes,
    required this.stockQuantity,
    required this.priceInPaise,
    required this.tier,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      sku: json['sku'] as String,
      attributes: Map<String, dynamic>.from(json['attributes'] as Map),
      stockQuantity: json['stockQuantity'] as int,
      priceInPaise: json['priceInPaise'] as int,
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
  final List<String> images;
  final Category category;
  final List<ProductVariant> variants;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
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
      images: (json['images'] as List).map((e) => e as String).toList(),
      category: Category.fromJson(json['category'] as Map<String, dynamic>),
      variants: (json['variants'] as List)
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  int get lowestPriceInPaise =>
      variants.map((v) => v.priceInPaise).reduce((a, b) => a < b ? a : b);
}
