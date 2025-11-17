// File: lib/services/restaurant_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../models/menu_model.dart';

/// Service untuk menangani logika bisnis terkait Restoran.
class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _cloudinary =
      CloudinaryPublic('drdfrxobm', 'katering_app', cache: false);

  /// Mengunggah gambar menu ke Cloudinary.
  /// Mengembalikan [String] berupa URL gambar yang aman.
  Future<String> _uploadMenuImage(File imageFile, String menuId) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'foto_menu',
          publicId: 'menu_${menuId}',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Gagal mengunggah foto menu.');
    }
  }

  /// Menambahkan menu baru ke subkoleksi 'menus'.
  Future<void> addMenu({
    required String restoId,
    required String namaMenu,
    required int harga,
    required File imageFile,
    required bool isAvailable,
  }) async {
    try {
      final menuDocRef = _firestore
          .collection('restaurants')
          .doc(restoId)
          .collection('menus')
          .doc();
      final menuId = menuDocRef.id;
      final fotoUrl = await _uploadMenuImage(imageFile, menuId);

      final newMenu = MenuModel(
        menuId: menuId,
        namaMenu: namaMenu,
        harga: harga,
        fotoUrl: fotoUrl,
        isAvailable: isAvailable,
        restaurantId: restoId,
        statusResto: 'verified', 
      );

      await menuDocRef.set(newMenu.toJson());
    } catch (e) {
      print('Error adding menu: $e');
      throw Exception('Gagal menambahkan menu baru.');
    }
  }

  /// Memperbarui data menu yang sudah ada.
  Future<void> updateMenu({
    required String restoId,
    required String menuId,
    required String namaMenu,
    required int harga,
    required bool isAvailable,
    String? existingFotoUrl,
    File? newImageFile,
    String? statusResto,
  }) async {
    try {
      String fotoUrl = existingFotoUrl ?? '';
      
      if (newImageFile != null) {
        fotoUrl = await _uploadMenuImage(newImageFile, menuId);
      }

      final updatedMenu = MenuModel(
        menuId: menuId,
        namaMenu: namaMenu,
        harga: harga,
        fotoUrl: fotoUrl,
        isAvailable: isAvailable,
        restaurantId: restoId,
        statusResto: statusResto ?? 'verified',
      );

      await _firestore
          .collection('restaurants')
          .doc(restoId)
          .collection('menus')
          .doc(menuId)
          .update(updatedMenu.toJson());
          
    } catch (e) {
      print('Error updating menu: $e');
      throw Exception('Gagal memperbarui menu.');
    }
  }
  
  /// Menghapus menu dari subkoleksi 'menus'.
  Future<void> deleteMenu({
    required String restoId,
    required String menuId,
  }) async {
    try {
      await _firestore
          .collection('restaurants')
          .doc(restoId)
          .collection('menus')
          .doc(menuId)
          .delete();
          
    } catch (e) {
      print('Error deleting menu: $e');
      throw Exception('Gagal menghapus menu.');
    }
  }

  /// [FUNGSI BARU] Memperbarui status beberapa pesanan sekaligus.
  Future<void> updateOrderStatusBatch(List<String> orderIds, String newStatus) async {
    if (orderIds.isEmpty) return;

    final batch = _firestore.batch();
    
    for (final orderId in orderIds) {
      final docRef = _firestore.collection('daily_orders').doc(orderId);
      batch.update(docRef, {'status': newStatus});
    }
    
    await batch.commit();
  }
}