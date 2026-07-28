class CartItem {
  final String id;
  final String variantId;
  final String sku;
  final int quantity;
  final int priceInPaise;
  final String tier;

  CartItem({
    required this.id,
    required this.variantId,
    required this.sku,
    required this.quantity,
    required this.priceInPaise,
    required this.tier,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      variantId: json['variantId'] as String,
      sku: json['sku'] as String,
      quantity: json['quantity'] as int,
      priceInPaise: json['priceInPaise'] as int,
      tier: json['tier'] as String,
    );
  }

  int get lineTotalInPaise => priceInPaise * quantity;
}
