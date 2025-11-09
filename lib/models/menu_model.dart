// File: lib/models/menu_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model data untuk item menu yang disimpan di Firestore.
class MenuModel {
  final String menuId;
  final String namaMenu;
  final int harga;
  final String fotoUrl;
  final bool isAvailable;
  final String restaurantId;
  final String statusResto;

  MenuModel({
    required this.menuId,
    required this.namaMenu,
    required this.harga,
    required this.fotoUrl,
    required this.isAvailable,
    required this.restaurantId,
    this.statusResto = 'pending',
  });

  /// Konversi dari DocumentSnapshot (Firestore) ke objek MenuModel.
  factory MenuModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>;
    return MenuModel(
      menuId: snap.id,
      namaMenu: data['namaMenu'] ?? '',
      harga: data['harga'] ?? 0,
      fotoUrl: data['fotoUrl'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      restaurantId: data['restaurantId'] ?? '',
      statusResto: data['statusResto'] ?? 'pending',
    );
  }

  /// Konversi dari objek MenuModel ke Map (untuk ditulis ke Firestore).
  Map<String, dynamic> toJson() {
    return {
      'namaMenu': namaMenu,
      'harga': harga,
      'fotoUrl': fotoUrl,
      'isAvailable': isAvailable,
      'restaurantId': restaurantId,
      'statusResto': statusResto,
    };
  }
}