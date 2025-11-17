// File: lib/models/daily_order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model data untuk satu dokumen pesanan harian
class DailyOrderModel {
  final String id;
  final String userId;
  final String subscriptionId;
  final String restaurantId;
  
  // Detail Menu
  final String namaMenu;
  final int harga;
  final String fotoUrl;

  // Detail Pengiriman
  final int day;
  final String mealTime;
  final Timestamp deliveryDate;
  final String status;

  DailyOrderModel({
    required this.id,
    required this.userId,
    required this.subscriptionId,
    required this.restaurantId,
    required this.namaMenu,
    required this.harga,
    required this.fotoUrl,
    required this.day,
    required this.mealTime,
    required this.deliveryDate,
    required this.status,
  });

  /// Konversi dari DocumentSnapshot (Firestore) ke objek DailyOrderModel.
  factory DailyOrderModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>;
    return DailyOrderModel(
      id: snap.id,
      userId: data['userId'] ?? '',
      subscriptionId: data['subscriptionId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      namaMenu: data['namaMenu'] ?? '',
      harga: data['harga'] ?? 0,
      fotoUrl: data['fotoUrl'] ?? '',
      day: data['day'] ?? 0,
      mealTime: data['mealTime'] ?? '',
      deliveryDate: data['deliveryDate'] ?? Timestamp.now(),
      status: data['status'] ?? 'confirmed',
    );
  }
}