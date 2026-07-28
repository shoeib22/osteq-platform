class TradeApplication {
  final String id;
  final String status;
  final String? rejectionReason;

  TradeApplication({required this.id, required this.status, this.rejectionReason});

  factory TradeApplication.fromJson(Map<String, dynamic> json) {
    return TradeApplication(
      id: json['id'] as String,
      status: json['status'] as String,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}
