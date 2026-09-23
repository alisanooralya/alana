/// Helpers for safely reading loosely typed values from JSON payloads.
library;

/// Returns [value] as a [String], or [fallback] when it is null.
String asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

/// Returns [value] as an [int], or [fallback] when it cannot be converted.
int asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
  }
  return fallback;
}

/// Returns [value] as an [int], or `null` when it is missing or unparsable.
int? asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }
  return null;
}

/// Returns [value] as a [num], or [fallback] when it cannot be converted.
num asNum(dynamic value, {num fallback = 0}) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? fallback;
  return fallback;
}

/// Returns [value] as a [double], or [fallback] when it cannot be converted.
double asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}
