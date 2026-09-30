import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:equatable/equatable.dart';

enum PingStatus { pending, approved, declined, expired, unavailable }

class PingLocation extends Equatable {
  final double lat;
  final double lng;
  final double accuracy;

  const PingLocation({
    required this.lat,
    required this.lng,
    required this.accuracy,
  });

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'accuracy': accuracy,
  };

  factory PingLocation.fromMap(Map<String, dynamic> map) {
    return PingLocation(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [lat, lng, accuracy];
}

class PingRequest extends Equatable {
  final String id;
  final String senderId;
  final String recipientId;
  final String reason;
  final PingStatus status;
  final PingLocation? location;
  final DateTime timestamp;
  final DateTime? respondedAt;
  final bool reciprocity;

  const PingRequest({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.reason,
    required this.status,
    this.location,
    required this.timestamp,
    this.respondedAt,
    this.reciprocity = false,
  });

  PingRequest copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? reason,
    PingStatus? status,
    PingLocation? location,
    DateTime? timestamp,
    DateTime? respondedAt,
    bool? reciprocity,
  }) {
    return PingRequest(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      respondedAt: respondedAt ?? this.respondedAt,
      reciprocity: reciprocity ?? this.reciprocity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'reason': reason,
      'status': status.name,
      if (location != null) 'location': location!.toMap(),
      'timestamp': fs.Timestamp.fromDate(timestamp),
      if (respondedAt != null)
        'respondedAt': fs.Timestamp.fromDate(respondedAt!),
      'reciprocity': reciprocity,
    };
  }

  factory PingRequest.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseTime(dynamic value) {
      if (value is fs.Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return PingRequest(
      id: id,
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      reason: map['reason'] ?? '',
      status: PingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PingStatus.pending,
      ),
      location: map['location'] != null
          ? PingLocation.fromMap(Map<String, dynamic>.from(map['location']))
          : null,
      timestamp: parseTime(map['timestamp']),
      respondedAt: map['respondedAt'] != null
          ? parseTime(map['respondedAt'])
          : null,
      reciprocity: map['reciprocity'] ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    recipientId,
    reason,
    status,
    location,
    timestamp,
    respondedAt,
    reciprocity,
  ];
}
