// Enums mirroring the frozen OpenAPI contract's enum fields exactly.
// Dart enum members are lowerCamelCase by convention, so each enum
// carries an [apiValue] mapping to the exact wire string, and a
// `fromApiValue` parser for the reverse direction. Do not add, remove,
// or reinterpret any of these values - they are frozen.

enum InjuryType { critical, serious, minor, pregnant, child }

extension InjuryTypeX on InjuryType {
  String get apiValue {
    switch (this) {
      case InjuryType.critical:
        return 'Critical';
      case InjuryType.serious:
        return 'Serious';
      case InjuryType.minor:
        return 'Minor';
      case InjuryType.pregnant:
        return 'Pregnant';
      case InjuryType.child:
        return 'Child';
    }
  }

  static InjuryType fromApiValue(String value) {
    switch (value) {
      case 'Critical':
        return InjuryType.critical;
      case 'Serious':
        return InjuryType.serious;
      case 'Minor':
        return InjuryType.minor;
      case 'Pregnant':
        return InjuryType.pregnant;
      case 'Child':
        return InjuryType.child;
      default:
        throw ArgumentError('Unknown injury_type value: $value');
    }
  }
}

enum EmergencyLevel { low, medium, high }

extension EmergencyLevelX on EmergencyLevel {
  String get apiValue {
    switch (this) {
      case EmergencyLevel.low:
        return 'LOW';
      case EmergencyLevel.medium:
        return 'MEDIUM';
      case EmergencyLevel.high:
        return 'HIGH';
    }
  }

  static EmergencyLevel fromApiValue(String value) {
    switch (value) {
      case 'LOW':
        return EmergencyLevel.low;
      case 'MEDIUM':
        return EmergencyLevel.medium;
      case 'HIGH':
        return EmergencyLevel.high;
      default:
        throw ArgumentError('Unknown emergency_level value: $value');
    }
  }
}

enum PriorityLevel { low, medium, high }

extension PriorityLevelX on PriorityLevel {
  String get apiValue {
    switch (this) {
      case PriorityLevel.low:
        return 'LOW';
      case PriorityLevel.medium:
        return 'MEDIUM';
      case PriorityLevel.high:
        return 'HIGH';
    }
  }

  static PriorityLevel fromApiValue(String value) {
    switch (value) {
      case 'LOW':
        return PriorityLevel.low;
      case 'MEDIUM':
        return PriorityLevel.medium;
      case 'HIGH':
        return PriorityLevel.high;
      default:
        throw ArgumentError('Unknown priority_level value: $value');
    }
  }
}

/// Frozen status values: PENDING, RECEIVED, ASSIGNED, RESCUED - the
/// only valid statuses across backend, frontend, and database.
enum SosStatus { pending, received, assigned, rescued }

extension SosStatusX on SosStatus {
  String get apiValue {
    switch (this) {
      case SosStatus.pending:
        return 'PENDING';
      case SosStatus.received:
        return 'RECEIVED';
      case SosStatus.assigned:
        return 'ASSIGNED';
      case SosStatus.rescued:
        return 'RESCUED';
    }
  }

  static SosStatus fromApiValue(String value) {
    switch (value) {
      case 'PENDING':
        return SosStatus.pending;
      case 'RECEIVED':
        return SosStatus.received;
      case 'ASSIGNED':
        return SosStatus.assigned;
      case 'RESCUED':
        return SosStatus.rescued;
      default:
        throw ArgumentError('Unknown status value: $value');
    }
  }
}
