// lib/models/energy_request.dart
import 'energy_listing.dart';

class EnergyRequest {
  final String id;
  final String buyerId;
  final String listingId;
  final double requestedEnergy;
  final double? offeredPricePerKwh;
  final double buyerLocationLat;
  final double buyerLocationLng;
  final String? message;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Additional fields for UI
  final EnergyListing? listing;
  final String? buyerName;
  final String? sellerName;

  EnergyRequest({
    required this.id,
    required this.buyerId,
    required this.listingId,
    required this.requestedEnergy,
    this.offeredPricePerKwh,
    required this.buyerLocationLat,
    required this.buyerLocationLng,
    this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.listing,
    this.buyerName,
    this.sellerName,
  });

  factory EnergyRequest.fromJson(Map<String, dynamic> json) {
    return EnergyRequest(
      id: json['id'],
      buyerId: json['buyer_id'],
      listingId: json['listing_id'],
      requestedEnergy: (json['requested_energy'] as num).toDouble(),
      offeredPricePerKwh: (json['offered_price_per_kwh'] as num?)?.toDouble(),
      buyerLocationLat: (json['buyer_location_lat'] as num).toDouble(),
      buyerLocationLng: (json['buyer_location_lng'] as num).toDouble(),
      message: json['message'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      listing: json['energy_listings'] != null 
          ? EnergyListing.fromJson(json['energy_listings']) 
          : null,
      buyerName: json['buyer_name'],
      sellerName: json['seller_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buyer_id': buyerId,
      'listing_id': listingId,
      'requested_energy': requestedEnergy,
      'offered_price_per_kwh': offeredPricePerKwh,
      'buyer_location_lat': buyerLocationLat,
      'buyer_location_lng': buyerLocationLng,
      'message': message,
      'status': status,
    };
  }

  EnergyRequest copyWith({
    String? id,
    String? buyerId,
    String? listingId,
    double? requestedEnergy,
    double? offeredPricePerKwh,
    double? buyerLocationLat,
    double? buyerLocationLng,
    String? message,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    EnergyListing? listing,
    String? buyerName,
    String? sellerName,
  }) {
    return EnergyRequest(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      listingId: listingId ?? this.listingId,
      requestedEnergy: requestedEnergy ?? this.requestedEnergy,
      offeredPricePerKwh: offeredPricePerKwh ?? this.offeredPricePerKwh,
      buyerLocationLat: buyerLocationLat ?? this.buyerLocationLat,
      buyerLocationLng: buyerLocationLng ?? this.buyerLocationLng,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      listing: listing ?? this.listing,
      buyerName: buyerName ?? this.buyerName,
      sellerName: sellerName ?? this.sellerName,
    );
  }
}