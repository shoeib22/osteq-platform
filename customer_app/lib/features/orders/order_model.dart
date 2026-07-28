class OrderItem {
  final String id;
  final String variantId;
  final int quantity;
  final int unitPriceInPaise;

  OrderItem({
    required this.id,
    required this.variantId,
    required this.quantity,
    required this.unitPriceInPaise,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      variantId: json['variantId'] as String,
      quantity: json['quantity'] as int,
      unitPriceInPaise: json['unitPriceInPaise'] as int,
    );
  }
}

class Order {
  final String id;
  final String status;
  final String shippingAddress;
  final String? trackingNumber;
  final int totalInPaise;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.status,
    required this.shippingAddress,
    this.trackingNumber,
    required this.totalInPaise,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      status: json['status'] as String,
      shippingAddress: json['shippingAddress'] as String,
      trackingNumber: json['trackingNumber'] as String?,
      totalInPaise: json['totalInPaise'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List)
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
