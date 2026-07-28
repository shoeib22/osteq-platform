class QuoteItem {
  final String id;
  final String? productVariantId;
  final String? description;
  final int quantity;
  final int? quotedUnitPriceInPaise;
  final String? notes;

  QuoteItem({
    required this.id,
    this.productVariantId,
    this.description,
    required this.quantity,
    this.quotedUnitPriceInPaise,
    this.notes,
  });

  factory QuoteItem.fromJson(Map<String, dynamic> json) {
    return QuoteItem(
      id: json['id'] as String,
      productVariantId: json['productVariantId'] as String?,
      description: json['description'] as String?,
      quantity: json['quantity'] as int,
      quotedUnitPriceInPaise: json['quotedUnitPriceInPaise'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

class QuoteMessage {
  final String id;
  final String? authorProfileId;
  final String? authorCustomerId;
  final String body;
  final DateTime createdAt;

  QuoteMessage({
    required this.id,
    this.authorProfileId,
    this.authorCustomerId,
    required this.body,
    required this.createdAt,
  });

  factory QuoteMessage.fromJson(Map<String, dynamic> json) {
    return QuoteMessage(
      id: json['id'] as String,
      authorProfileId: json['authorProfileId'] as String?,
      authorCustomerId: json['authorCustomerId'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isFromStaff => authorProfileId != null;
}

class Quote {
  final String id;
  final String status;
  final DateTime createdAt;
  final List<QuoteItem> items;
  final List<QuoteMessage> messages;

  Quote({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.items,
    this.messages = const [],
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List)
          .map((i) => QuoteItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((m) => QuoteMessage.fromJson(m as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  bool get allItemsPriced => items.every((i) => i.quotedUnitPriceInPaise != null);

  int get totalInPaise =>
      items.fold(0, (sum, i) => sum + (i.quotedUnitPriceInPaise ?? 0) * i.quantity);
}
