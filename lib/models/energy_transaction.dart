// lib/models/energy_transaction.dart
class EnergyTransaction {
  final String id;
  final String requestId;
  final String sellerId;
  final String buyerId;
  final double? energyTransferred;
  final double? finalPricePerKwh;
  final double? totalAmount;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? sellerLocationLat;
  final double? sellerLocationLng;
  final double? buyerLocationLat;
  final double? buyerLocationLng;
  final String status;
  final String paymentStatus;
  final int? sellerRating;
  final int? buyerRating;
  final String? sellerReview;
  final String? buyerReview;
  final DateTime createdAt;
  final DateTime updatedAt;

  EnergyTransaction({
    required this.id,
    required this.requestId,
    required this.sellerId,
    required this.buyerId,
    this.energyTransferred,
    this.finalPricePerKwh,
    this.totalAmount,
    this.startTime,
    this.endTime,
    this.sellerLocationLat,
    this.sellerLocationLng,
    this.buyerLocationLat,
    this.buyerLocationLng,
    required this.status,
    required this.paymentStatus,
    this.sellerRating,
    this.buyerRating,
    this.sellerReview,
    this.buyerReview,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EnergyTransaction.fromJson(Map<String, dynamic> json) {
    return EnergyTransaction(
      id: json['id'],
      requestId: json['request_id'],
      sellerId: json['seller_id'],
      buyerId: json['buyer_id'],
      energyTransferred: (json['energy_transferred'] as num?)?.toDouble(),
      finalPricePerKwh: (json['final_price_per_kwh'] as num?)?.toDouble(),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      sellerLocationLat: (json['seller_location_lat'] as num?)?.toDouble(),
      sellerLocationLng: (json['seller_location_lng'] as num?)?.toDouble(),
      buyerLocationLat: (json['buyer_location_lat'] as num?)?.toDouble(),
      buyerLocationLng: (json['buyer_location_lng'] as num?)?.toDouble(),
      status: json['status'],
      paymentStatus: json['payment_status'],
      sellerRating: json['seller_rating'],
      buyerRating: json['buyer_rating'],
      sellerReview: json['seller_review'],
      buyerReview: json['buyer_review'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'seller_id': sellerId,
      'buyer_id': buyerId,
      'energy_transferred': energyTransferred,
      'final_price_per_kwh': finalPricePerKwh,
      'total_amount': totalAmount,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'seller_location_lat': sellerLocationLat,
      'seller_location_lng': sellerLocationLng,
      'buyer_location_lat': buyerLocationLat,
      'buyer_location_lng': buyerLocationLng,
      'status': status,
      'payment_status': paymentStatus,
      'seller_rating': sellerRating,
      'buyer_rating': buyerRating,
      'seller_review': sellerReview,
      'buyer_review': buyerReview,
    };
  }
}