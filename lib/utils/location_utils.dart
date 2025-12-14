// File: lib/utils/location_utils.dart
import 'dart:math' show cos, sqrt, asin;

class LocationUtils {
  /// Menghitung jarak (dalam KM) menggunakan Haversine Formula
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295; // Math.PI / 180
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * Radius Bumi
  }

  /// Format jarak
  static String formatDistance(double distanceInKm) {
    return '${distanceInKm.toStringAsFixed(1)} km';
  }
}