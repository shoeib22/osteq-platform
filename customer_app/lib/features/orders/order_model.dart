class OrderItem {
  final String id;
  final String variantId;
  final int quantity;
  final double unitPriceInRupees;
  final String? sku;
  final String? productName;

  OrderItem({
    required this.id,
    required this.variantId,
    required this.quantity,
    required this.unitPriceInRupees,
    this.sku,
    this.productName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final variant = json['variant'] as Map<String, dynamic>?;
    final product = variant?['product'] as Map<String, dynamic>?;
    return OrderItem(
      id: json['id'] as String,
      variantId: json['variantId'] as String,
      quantity: json['quantity'] as int,
      unitPriceInRupees: (json['unitPriceInRupees'] as num).toDouble(),
      sku: variant?['sku'] as String?,
      productName: product?['name'] as String?,
    );
  }

  double get lineTotalInRupees => unitPriceInRupees * quantity;
}

class Order {
  final String id;
  final String status;
  final String shippingAddress;
  final String? trackingNumber;
  final String? trackingUrl;
  final bool hasInvoicePdf;
  final double totalInRupees;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String? customerEmail;

  Order({
    required this.id,
    required this.status,
    required this.shippingAddress,
    this.trackingNumber,
    this.trackingUrl,
    required this.hasInvoicePdf,
    required this.totalInRupees,
    required this.createdAt,
    required this.items,
    this.customerEmail,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    return Order(
      id: json['id'] as String,
      status: json['status'] as String,
      shippingAddress: json['shippingAddress'] as String,
      trackingNumber: json['trackingNumber'] as String?,
      trackingUrl: json['trackingUrl'] as String?,
      hasInvoicePdf: json['hasInvoicePdf'] as bool? ?? false,
      totalInRupees: (json['totalInRupees'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List)
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      customerEmail: customer?['email'] as String?,
    );
  }
}
