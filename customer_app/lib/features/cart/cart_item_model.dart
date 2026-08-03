class CartItem {
  final String id;
  final String variantId;
  final String sku;
  final int quantity;
  final double priceInRupees;
  final String tier;

  CartItem({
    required this.id,
    required this.variantId,
    required this.sku,
    required this.quantity,
    required this.priceInRupees,
    required this.tier,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      variantId: json['variantId'] as String,
      sku: json['sku'] as String,
      quantity: json['quantity'] as int,
      priceInRupees: (json['priceInRupees'] as num).toDouble(),
      tier: json['tier'] as String,
    );
  }

  double get lineTotalInRupees => priceInRupees * quantity;
}
