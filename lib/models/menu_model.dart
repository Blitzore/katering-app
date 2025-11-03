// File: lib/models/menu_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model data untuk item menu yang disimpan di Firestore.
class MenuModel {
  final String menuId;
  final String namaMenu;
  final int harga;
  final String fotoUrl;
  final bool isAvailable;

  MenuModel({
    required this.menuId,
    required this.namaMenu,
    required this.harga,
    required this.fotoUrl,
    required this.isAvailable,
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
    );
  }

  /// Konversi dari objek MenuModel ke Map (untuk ditulis ke Firestore).
  Map<String, dynamic> toJson() {
    return {
      // menuId tidak perlu disimpan di dalam data, karena itu adalah ID dokumen
      'namaMenu': namaMenu,
      'harga': harga,
      'fotoUrl': fotoUrl,
      'isAvailable': isAvailable,
    };
  }
}