class Address {
  final String id;
  final String label;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String? phone;
  final bool isDefault;

  Address({
    required this.id,
    required this.label,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    this.phone,
    required this.isDefault,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String,
      label: json['label'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postalCode'] as String,
      country: json['country'] as String,
      phone: json['phone'] as String?,
      isDefault: json['isDefault'] as bool,
    );
  }

  String get summary {
    final parts = [line1, if (line2 != null && line2!.isNotEmpty) line2, city, state, postalCode, country];
    return parts.join(', ');
  }
}
