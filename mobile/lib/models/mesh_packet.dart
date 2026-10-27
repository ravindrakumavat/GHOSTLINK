import 'dart:convert';
import 'dart:typed_data';

import 'enums.dart';
import 'sos_request.dart';

/// Standard ResQMesh BLE Mesh Transport Packet.
/// Wraps an SOS distress payload with routing metadata, hop limits,
/// and a unique messageId for duplicate-prevention across relay nodes.
/// Supports both full JSON serialization and ultra-compact BLE binary encoding.
class MeshPacket {
  final String messageId;
  final String originDeviceId;
  final DateTime createdAt;
  final int hopCount;
  final int maxHops;
  final SosRequestCreate payload;
  final bool isDelivered;

  const MeshPacket({
    required this.messageId,
    required this.originDeviceId,
    required this.createdAt,
    required this.hopCount,
    this.maxHops = 5,
    required this.payload,
    this.isDelivered = false,
  });

  /// Increments hop count for relay forwarding.
  MeshPacket incrementHop() {
    return MeshPacket(
      messageId: messageId,
      originDeviceId: originDeviceId,
      createdAt: createdAt,
      hopCount: hopCount + 1,
      maxHops: maxHops,
      payload: payload,
      isDelivered: isDelivered,
    );
  }

  /// Marks packet as successfully delivered by an internet gateway.
  MeshPacket markDelivered() {
    return MeshPacket(
      messageId: messageId,
      originDeviceId: originDeviceId,
      createdAt: createdAt,
      hopCount: hopCount,
      maxHops: maxHops,
      payload: payload,
      isDelivered: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'origin_device_id': originDeviceId,
      'created_at': createdAt.toIso8601String(),
      'hop_count': hopCount,
      'max_hops': maxHops,
      'payload': payload.toJson(),
      'is_delivered': isDelivered,
    };
  }

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    return MeshPacket(
      messageId: json['message_id'] as String,
      originDeviceId: json['origin_device_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      hopCount: json['hop_count'] as int? ?? 0,
      maxHops: json['max_hops'] as int? ?? 5,
      payload: SosRequestCreate.fromJson(
        json['payload'] as Map<String, dynamic>,
      ),
      isDelivered: json['is_delivered'] as bool? ?? false,
    );
  }

  Uint8List toBytes() {
    final jsonStr = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  factory MeshPacket.fromBytes(List<int> bytes) {
    // Check if it's compact binary (starts with magic byte 0x52 'R')
    if (bytes.isNotEmpty && bytes[0] == 0x52 && bytes.length >= 24) {
      try {
        return MeshPacket.fromCompactBytes(bytes);
      } catch (_) {}
    }

    final jsonStr = utf8.decode(bytes);
    final Map<String, dynamic> decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    return MeshPacket.fromJson(decoded);
  }

  /// Compact Binary Encoding (<60 bytes) for BLE advertisement and low-MTU frames:
  /// [0] Magic: 0x52 ('R')
  /// [1] Version: 1
  /// [2] hopCount
  /// [3] maxHops
  /// [4] injuryType index
  /// [5] emergencyLevel index
  /// [6] victimCount
  /// [7] batteryPercentage
  /// [8..15] latitude (Float64)
  /// [16..23] longitude (Float64)
  /// [24..31] timestamp (Int64 millis)
  /// [32] nameLen
  /// [33..33+nameLen] victimName
  /// [..] deviceIdLen
  /// [..] deviceId
  Uint8List toCompactBytes() {
    final nameBytes = utf8.encode(payload.victimName);
    final devBytes = utf8.encode(originDeviceId);
    final msgBytes = utf8.encode(messageId);

    final totalLen = 34 + nameBytes.length + 1 + devBytes.length + 1 + msgBytes.length;
    final buffer = ByteData(totalLen);

    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 1); // v1
    buffer.setUint8(2, hopCount);
    buffer.setUint8(3, maxHops);
    buffer.setUint8(4, payload.injuryType.index);
    buffer.setUint8(5, payload.emergencyLevel.index);
    buffer.setUint8(6, payload.victimCount);
    buffer.setUint8(7, payload.batteryPercentage);
    buffer.setFloat64(8, payload.latitude);
    buffer.setFloat64(16, payload.longitude);
    buffer.setInt64(24, createdAt.millisecondsSinceEpoch);

    buffer.setUint8(32, nameBytes.length);
    int offset = 33;
    for (int i = 0; i < nameBytes.length; i++) {
      buffer.setUint8(offset++, nameBytes[i]);
    }

    buffer.setUint8(offset++, devBytes.length);
    for (int i = 0; i < devBytes.length; i++) {
      buffer.setUint8(offset++, devBytes[i]);
    }

    buffer.setUint8(offset++, msgBytes.length);
    for (int i = 0; i < msgBytes.length; i++) {
      buffer.setUint8(offset++, msgBytes[i]);
    }

    return buffer.buffer.asUint8List();
  }

  factory MeshPacket.fromCompactBytes(List<int> bytes) {
    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

    final hopCount = byteData.getUint8(2);
    final maxHops = byteData.getUint8(3);
    final injuryIdx = byteData.getUint8(4);
    final emergencyIdx = byteData.getUint8(5);
    final victimCount = byteData.getUint8(6);
    final battery = byteData.getUint8(7);
    final lat = byteData.getFloat64(8);
    final lng = byteData.getFloat64(16);
    final millis = byteData.getInt64(24);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

    final nameLen = byteData.getUint8(32);
    int offset = 33;
    final nameBytes = bytes.sublist(offset, offset + nameLen);
    final victimName = utf8.decode(nameBytes);
    offset += nameLen;

    final devLen = byteData.getUint8(offset++);
    final devBytes = bytes.sublist(offset, offset + devLen);
    final deviceId = utf8.decode(devBytes);
    offset += devLen;

    String messageId = 'mesh_${millis}_$deviceId';
    if (offset < bytes.length) {
      final msgLen = byteData.getUint8(offset++);
      if (offset + msgLen <= bytes.length) {
        messageId = utf8.decode(bytes.sublist(offset, offset + msgLen));
      }
    }

    final injuryType = InjuryType.values[injuryIdx.clamp(0, InjuryType.values.length - 1)];
    final emergencyLevel = EmergencyLevel.values[emergencyIdx.clamp(0, EmergencyLevel.values.length - 1)];

    return MeshPacket(
      messageId: messageId,
      originDeviceId: deviceId,
      createdAt: createdAt,
      hopCount: hopCount,
      maxHops: maxHops,
      payload: SosRequestCreate(
        victimName: victimName,
        injuryType: injuryType,
        victimCount: victimCount,
        emergencyLevel: emergencyLevel,
        latitude: lat,
        longitude: lng,
        batteryPercentage: battery,
        deviceId: deviceId,
      ),
    );
  }
}

/// Standard ResQMesh BLE Acknowledgement (ACK) Frame.
class MeshAck {
  final String messageId;
  final String responderDeviceId;
  final DateTime ackedAt;

  const MeshAck({
    required this.messageId,
    required this.responderDeviceId,
    required this.ackedAt,
  });

  Map<String, dynamic> toJson() => {
    'type': 'ACK',
    'message_id': messageId,
    'responder_device_id': responderDeviceId,
    'acked_at': ackedAt.toIso8601String(),
  };

  factory MeshAck.fromJson(Map<String, dynamic> json) => MeshAck(
    messageId: json['message_id'] as String,
    responderDeviceId: json['responder_device_id'] as String? ?? 'PEER',
    ackedAt: json['acked_at'] != null ? DateTime.parse(json['acked_at'] as String) : DateTime.now().toUtc(),
  );

  Uint8List toBytes() {
    return Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
  }

  factory MeshAck.fromBytes(List<int> bytes) {
    final str = utf8.decode(bytes);
    final decoded = jsonDecode(str) as Map<String, dynamic>;
    return MeshAck.fromJson(decoded);
  }

  static bool isAckPayload(List<int> bytes) {
    try {
      final str = utf8.decode(bytes);
      return str.contains('"type":"ACK"') || str.contains('"type": "ACK"');
    } catch (_) {
      return false;
    }
  }
}
