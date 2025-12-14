// File: lib/models/restaurant_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantModel {
  final String id;
  final String namaToko;
  final String alamat;
  final String email;
  final String status; // 'pending', 'verified', 'rejected'
  final String? fotoUrl;
  
  // --- TAMBAHAN MINGGU 8 (LOKASI) ---
  final double latitude;
  final double longitude;

  RestaurantModel({
    required this.id,
    required this.namaToko,
    required this.alamat,
    required this.email,
    required this.status,
    this.fotoUrl,
    // Default 0.0 jika tidak ada data
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  // Factory untuk membuat object dari data Firestore
  factory RestaurantModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RestaurantModel(
      id: doc.id,
      namaToko: data['namaToko'] ?? '',
      alamat: data['alamat'] ?? '',
      email: data['email'] ?? '',
      status: data['status'] ?? 'pending',
      fotoUrl: data['fotoUrl'],
      
      // Ambil data latitude/longitude (pastikan dikonversi ke double)
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Method untuk mengubah object menjadi Map (jika perlu simpan ke DB)
  Map<String, dynamic> toJson() {
    return {
      'namaToko': namaToko,
      'alamat': alamat,
      'email': email,
      'status': status,
      'fotoUrl': fotoUrl,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}