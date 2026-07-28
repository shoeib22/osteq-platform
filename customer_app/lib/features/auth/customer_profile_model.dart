class CustomerProfile {
  final String id;
  final String email;
  final String? businessName;
  final String? businessType;
  final String? phone;
  final String accountStatus;

  CustomerProfile({
    required this.id,
    required this.email,
    this.businessName,
    this.businessType,
    this.phone,
    required this.accountStatus,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      businessName: json['businessName'] as String?,
      businessType: json['businessType'] as String?,
      phone: json['phone'] as String?,
      accountStatus: json['accountStatus'] as String,
    );
  }

  bool get isTradeApproved => accountStatus == 'TRADE_APPROVED';
}
