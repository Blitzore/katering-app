// File: lib/services/restaurant_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../models/menu_model.dart';

/// Service untuk menangani logika bisnis terkait Restoran (khususnya Menu).
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
      // 1. Buat dokumen baru untuk mendapatkan ID unik
      final menuDocRef = _firestore
          .collection('restaurants')
          .doc(restoId)
          .collection('menus')
          .doc();
      final menuId = menuDocRef.id;

      // 2. Upload gambar menggunakan ID unik
      final fotoUrl = await _uploadMenuImage(imageFile, menuId);

      // 3. Buat objek MenuModel
      final newMenu = MenuModel(
        menuId: menuId,
        namaMenu: namaMenu,
        harga: harga,
        fotoUrl: fotoUrl,
        isAvailable: isAvailable,
        restaurantId: restoId,
        statusResto: 'verified', // Menu baru otomatis verified (resto sudah verified)
      );

      // 4. Tulis data ke Firestore
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
    String? existingFotoUrl, // URL foto lama
    File? newImageFile, // Gambar baru (opsional)
    String? statusResto, // Status lama
  }) async {
    try {
      String fotoUrl = existingFotoUrl ?? '';
      
      // 1. Jika ada gambar baru, upload dan ganti URL-nya
      if (newImageFile != null) {
        fotoUrl = await _uploadMenuImage(newImageFile, menuId);
      }

      // 2. Buat objek MenuModel yang sudah diupdate
      final updatedMenu = MenuModel(
        menuId: menuId,
        namaMenu: namaMenu,
        harga: harga,
        fotoUrl: fotoUrl, // URL baru atau URL lama
        isAvailable: isAvailable,
        restaurantId: restoId,
        statusResto: statusResto ?? 'verified', // Pertahankan status lama
      );

      // 3. Update data di Firestore
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
}