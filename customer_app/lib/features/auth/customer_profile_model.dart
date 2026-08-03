class CustomerProfile {
  final String id;
  final String email;
  final String? businessName;
  final String? businessType;
  final String? phone;
  final String accountStatus;
  final String? latestTradeApplicationStatus;

  CustomerProfile({
    required this.id,
    required this.email,
    this.businessName,
    this.businessType,
    this.phone,
    required this.accountStatus,
    this.latestTradeApplicationStatus,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      businessName: json['businessName'] as String?,
      businessType: json['businessType'] as String?,
      phone: json['phone'] as String?,
      accountStatus: json['accountStatus'] as String,
      latestTradeApplicationStatus: json['latestTradeApplicationStatus'] as String?,
    );
  }

  bool get isTradeApproved => accountStatus == 'TRADE_APPROVED';

  // accountStatus defaults to PENDING for every customer regardless of whether they've
  // ever applied for trade — it only becomes meaningful once staff approve/reject an
  // application. Whether an application is actually under review has to come from the
  // application record itself, not this profile-level default.
  bool get hasPendingTradeApplication => latestTradeApplicationStatus == 'PENDING';
}
