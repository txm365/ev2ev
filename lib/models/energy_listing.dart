// lib/models/energy_listing.dart
class EnergyListing {
  final String id;
  final String sellerId;
  final double pricePerKwh;
  final double availableEnergy;
  final double minEnergySale;
  final double maxEnergySale;
  final double locationLat;
  final double locationLng;
  final String? locationAddress;
  final String vehicleType;
  final String connectorType;
  final DateTime availabilityStart;
  final DateTime? availabilityEnd;
  final String status;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Additional fields for UI
  final String? sellerName;
  final double? distance;

  EnergyListing({
    required this.id,
    required this.sellerId,
    required this.pricePerKwh,
    required this.availableEnergy,
    required this.minEnergySale,
    required this.maxEnergySale,
    required this.locationLat,
    required this.locationLng,
    this.locationAddress,
    required this.vehicleType,
    required this.connectorType,
    required this.availabilityStart,
    this.availabilityEnd,
    required this.status,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.sellerName,
    this.distance,
  });

  factory EnergyListing.fromJson(Map<String, dynamic> json) {
    return EnergyListing(
      id: json['id'],
      sellerId: json['seller_id'],
      pricePerKwh: (json['price_per_kwh'] as num).toDouble(),
      availableEnergy: (json['available_energy'] as num).toDouble(),
      minEnergySale: (json['min_energy_sale'] as num).toDouble(),
      maxEnergySale: (json['max_energy_sale'] as num?)?.toDouble() ?? 0.0,
      locationLat: (json['location_lat'] as num).toDouble(),
      locationLng: (json['location_lng'] as num).toDouble(),
      locationAddress: json['location_address'],
      vehicleType: json['vehicle_type'],
      connectorType: json['connector_type'],
      availabilityStart: DateTime.parse(json['availability_start']),
      availabilityEnd: json['availability_end'] != null 
          ? DateTime.parse(json['availability_end']) 
          : null,
      status: json['status'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      sellerName: json['seller_name'],
      distance: (json['distance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_id': sellerId,
      'price_per_kwh': pricePerKwh,
      'available_energy': availableEnergy,
      'min_energy_sale': minEnergySale,
      'max_energy_sale': maxEnergySale,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'location_address': locationAddress,
      'vehicle_type': vehicleType,
      'connector_type': connectorType,
      'availability_start': availabilityStart.toIso8601String(),
      'availability_end': availabilityEnd?.toIso8601String(),
      'status': status,
      'description': description,
    };
  }

  EnergyListing copyWith({
    String? id,
    String? sellerId,
    double? pricePerKwh,
    double? availableEnergy,
    double? minEnergySale,
    double? maxEnergySale,
    double? locationLat,
    double? locationLng,
    String? locationAddress,
    String? vehicleType,
    String? connectorType,
    DateTime? availabilityStart,
    DateTime? availabilityEnd,
    String? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sellerName,
    double? distance,
  }) {
    return EnergyListing(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      pricePerKwh: pricePerKwh ?? this.pricePerKwh,
      availableEnergy: availableEnergy ?? this.availableEnergy,
      minEnergySale: minEnergySale ?? this.minEnergySale,
      maxEnergySale: maxEnergySale ?? this.maxEnergySale,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationAddress: locationAddress ?? this.locationAddress,
      vehicleType: vehicleType ?? this.vehicleType,
      connectorType: connectorType ?? this.connectorType,
      availabilityStart: availabilityStart ?? this.availabilityStart,
      availabilityEnd: availabilityEnd ?? this.availabilityEnd,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sellerName: sellerName ?? this.sellerName,
      distance: distance ?? this.distance,
    );
  }
}