// File: lib/services/restaurant_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http/http.dart' as http; // Import HTTP
import 'dart:convert'; // Import JSON
import '../models/menu_model.dart';

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _cloudinary = CloudinaryPublic('drdfrxobm', 'katering_app', cache: false);

  // --- FUNGSI LAMA (TETAP ADA) ---
  
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

  // --- [FUNGSI BARU: AUTO-ASSIGN] ---

  /// Memanggil Backend Vercel untuk mencari driver terdekat (5KM)
  /// dan memberikan tugas secara otomatis.
  Future<void> autoAssignOrdersToDriver(List<String> orderIds) async {
    try {
      // GANTI URL INI DENGAN URL VERCEL ANDA
      final url = Uri.parse('https://katering-app-backend.vercel.app/markReadyAndAutoAssign');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderIds': orderIds}),
      );

      if (response.statusCode != 200) {
        // Jika gagal (misal: tidak ada driver 5km), lempar error agar UI tahu
        throw Exception(response.body); 
      }
    } catch (e) {
      print('Error auto-assign: $e');
      rethrow; // Teruskan error ke UI untuk ditampilkan di SnackBar
    }
  }
}