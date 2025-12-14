// File: lib/models/daily_order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyOrderModel {
  final String orderId;
  final int day;
  final String mealTime;
  final String menuId;
  final String namaMenu;
  final int harga;
  final String fotoUrl;
  final Timestamp deliveryDate;
  final String status; 
  final String userId;
  final String restaurantId;
  final String? driverId;
  
  // --- TAMBAHAN COMMIT 3 ---
  final String? proofPhotoUrl; // Bukti Foto Driver
  final int shippingCost;      // Ongkir (Masuk ke Admin)

  DailyOrderModel({
    required this.orderId,
    required this.day,
    required this.mealTime,
    required this.menuId,
    required this.namaMenu,
    required this.harga,
    required this.fotoUrl,
    required this.deliveryDate,
    required this.status,
    required this.userId,
    required this.restaurantId,
    this.driverId,
    this.proofPhotoUrl,
    this.shippingCost = 0, // Default 0
  });

  factory DailyOrderModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyOrderModel(
      orderId: doc.id,
      day: data['day'] ?? 1,
      mealTime: data['mealTime'] ?? '',
      menuId: data['menuId'] ?? '',
      namaMenu: data['namaMenu'] ?? '',
      harga: data['harga'] ?? 0,
      fotoUrl: data['fotoUrl'] ?? '',
      deliveryDate: data['deliveryDate'] ?? Timestamp.now(),
      status: data['status'] ?? 'confirmed',
      userId: data['userId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      driverId: data['driverId'],
      proofPhotoUrl: data['proofPhotoUrl'],
      shippingCost: data['shippingCost'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'mealTime': mealTime,
      'menuId': menuId,
      'namaMenu': namaMenu,
      'harga': harga,
      'fotoUrl': fotoUrl,
      'deliveryDate': deliveryDate,
      'status': status,
      'userId': userId,
      'restaurantId': restaurantId,
      'driverId': driverId,
      'proofPhotoUrl': proofPhotoUrl,
      'shippingCost': shippingCost,
    };
  }
}