import 'enums.dart';

/// Mirrors the `SosRequest` schema in the frozen OpenAPI contract
/// field-for-field. Dart fields use lowerCamelCase per convention;
/// [toJson]/[fromJson] handle the snake_case wire format so nothing
/// outside this file needs to know the difference.
class SosRequest {
  final String uuid;
  final String victimName;
  final InjuryType injuryType;
  final int victimCount;
  final EmergencyLevel emergencyLevel;
  final double latitude;
  final double longitude;
  final int batteryPercentage;
  final String deviceId;
  final double priorityScore;
  final PriorityLevel priorityLevel;
  final SosStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SosRequest({
    required this.uuid,
    required this.victimName,
    required this.injuryType,
    required this.victimCount,
    required this.emergencyLevel,
    required this.latitude,
    required this.longitude,
    required this.batteryPercentage,
    required this.deviceId,
    required this.priorityScore,
    required this.priorityLevel,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SosRequest.fromJson(Map<String, dynamic> json) {
    return SosRequest(
      uuid: json['uuid'] as String,
      victimName: json['victim_name'] as String,
      injuryType: InjuryTypeX.fromApiValue(json['injury_type'] as String),
      victimCount: json['victim_count'] as int,
      emergencyLevel:
          EmergencyLevelX.fromApiValue(json['emergency_level'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      batteryPercentage: json['battery_percentage'] as int,
      deviceId: json['device_id'] as String,
      priorityScore: (json['priority_score'] as num).toDouble(),
      priorityLevel:
          PriorityLevelX.fromApiValue(json['priority_level'] as String),
      status: SosStatusX.fromApiValue(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'victim_name': victimName,
      'injury_type': injuryType.apiValue,
      'victim_count': victimCount,
      'emergency_level': emergencyLevel.apiValue,
      'latitude': latitude,
      'longitude': longitude,
      'battery_percentage': batteryPercentage,
      'device_id': deviceId,
      'priority_score': priorityScore,
      'priority_level': priorityLevel.apiValue,
      'status': status.apiValue,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Request payload for `POST /api/sos`. Deliberately excludes the
/// server-computed fields (uuid, priority_score, priority_level,
/// status, created_at, updated_at) since the contract's
/// `SosRequestCreate` schema never accepts them from the client.
class SosRequestCreate {
  final String victimName;
  final InjuryType injuryType;
  final int victimCount;
  final EmergencyLevel emergencyLevel;
  final double latitude;
  final double longitude;
  final int batteryPercentage;
  final String deviceId;

  const SosRequestCreate({
    required this.victimName,
    required this.injuryType,
    required this.victimCount,
    required this.emergencyLevel,
    required this.latitude,
    required this.longitude,
    required this.batteryPercentage,
    required this.deviceId,
  });

  factory SosRequestCreate.fromJson(Map<String, dynamic> json) {
    return SosRequestCreate(
      victimName: json['victim_name'] as String,
      injuryType: InjuryTypeX.fromApiValue(json['injury_type'] as String),
      victimCount: json['victim_count'] as int,
      emergencyLevel:
          EmergencyLevelX.fromApiValue(json['emergency_level'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      batteryPercentage: json['battery_percentage'] as int,
      deviceId: json['device_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'victim_name': victimName,
      'injury_type': injuryType.apiValue,
      'victim_count': victimCount,
      'emergency_level': emergencyLevel.apiValue,
      'latitude': latitude,
      'longitude': longitude,
      'battery_percentage': batteryPercentage,
      'device_id': deviceId,
    };
  }
}

/// Queued SOS record stored in the local outbox when network is offline.
/// Preserves complete original payload, creation timestamp, and a unique local identifier.
class QueuedSos {
  final String localId;
  final SosRequestCreate payload;
  final DateTime queuedAt;

  const QueuedSos({
    required this.localId,
    required this.payload,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'payload': payload.toJson(),
      'queued_at': queuedAt.toIso8601String(),
    };
  }

  factory QueuedSos.fromJson(Map<String, dynamic> json) {
    return QueuedSos(
      localId: json['local_id'] as String,
      payload: SosRequestCreate.fromJson(
        json['payload'] as Map<String, dynamic>,
      ),
      queuedAt: DateTime.parse(json['queued_at'] as String),
    );
  }
}
