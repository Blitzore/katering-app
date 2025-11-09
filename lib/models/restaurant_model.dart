// File: lib/models/restaurant_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model data untuk Dokumen Restoran
class RestaurantModel {
  final String id;
  final String namaToko;
  final String alamat;
  final String email;
  final String status;
  // Tambahkan field lain jika perlu, misal: fotoTokoUrl

  RestaurantModel({
    required this.id,
    required this.namaToko,
    required this.alamat,
    required this.email,
    required this.status,
  });

  /// Konversi dari DocumentSnapshot (Firestore) ke objek RestaurantModel.
  factory RestaurantModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>;
    return RestaurantModel(
      id: snap.id,
      namaToko: data['namaToko'] ?? '',
      alamat: data['alamat'] ?? '',
      email: data['email'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }
}