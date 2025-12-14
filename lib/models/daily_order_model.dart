// File: lib/models/daily_order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyOrderModel {
  final String orderId;
  final String subscriptionId;
  final String userId;
  final String restaurantId;
  
  // Info Menu
  final String menuId;
  final String namaMenu;
  final String fotoUrl;
  final int harga;
  
  // Info Waktu & Status
  final Timestamp deliveryDate;
  final String mealTime; // "Makan Siang" / "Makan Malam"
  final String status;   // pending, confirmed, assigned, ready_for_pickup, on_delivery, completed
  final Timestamp? createdAt;
  
  // Info Keuangan
  final int shippingCost;

  // --- FITUR BARU (WEEK 8) ---
  final String? driverId;       // ID Driver yang mengambil
  final String? driverName;     // Nama Driver
  final String? proofPhotoUrl;  // Bukti foto setelah diantar

  DailyOrderModel({
    required this.orderId,
    required this.subscriptionId,
    required this.userId,
    required this.restaurantId,
    required this.menuId,
    required this.namaMenu,
    required this.fotoUrl,
    required this.harga,
    required this.deliveryDate,
    required this.mealTime,
    required this.status,
    this.createdAt,
    this.shippingCost = 0,
    // Field baru opsional (bisa null)
    this.driverId,
    this.driverName,
    this.proofPhotoUrl,
  });

  /// Factory untuk mengubah Dokumen Firestore menjadi Object Dart
  factory DailyOrderModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DailyOrderModel(
      orderId: doc.id,
      subscriptionId: data['subscriptionId'] ?? '',
      userId: data['userId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      menuId: data['menuId'] ?? '',
      namaMenu: data['namaMenu'] ?? 'Menu Tidak Diketahui',
      fotoUrl: data['fotoUrl'] ?? '',
      harga: (data['harga'] ?? 0).toInt(),
      deliveryDate: data['deliveryDate'] ?? Timestamp.now(),
      mealTime: data['mealTime'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'],
      shippingCost: (data['shippingCost'] ?? 0).toInt(),
      
      // --- BACA DATA DRIVER & BUKTI ---
      driverId: data['driverId'],           // null jika belum dapat driver
      driverName: data['driverName'],       // null jika belum dapat driver
      proofPhotoUrl: data['proofPhotoUrl'], // null jika belum diantar
    );
  }

  /// Method untuk mengubah Object Dart kembali menjadi Map (JSON)
  /// Berguna jika kita ingin menyimpan/update data ke Firestore
  Map<String, dynamic> toMap() {
    return {
      'subscriptionId': subscriptionId,
      'userId': userId,
      'restaurantId': restaurantId,
      'menuId': menuId,
      'namaMenu': namaMenu,
      'fotoUrl': fotoUrl,
      'harga': harga,
      'deliveryDate': deliveryDate,
      'mealTime': mealTime,
      'status': status,
      'createdAt': createdAt,
      'shippingCost': shippingCost,
      'driverId': driverId,
      'driverName': driverName,
      'proofPhotoUrl': proofPhotoUrl,
    };
  }
}