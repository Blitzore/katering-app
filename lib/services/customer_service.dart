// File: lib/services/customer_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_model.dart';
import '../models/restaurant_model.dart'; // Import model baru

/// Service untuk menangani logika bisnis terkait Pelanggan.
class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mengambil stream daftar restoran yang statusnya 'verified'.
  Stream<List<RestaurantModel>> getVerifiedRestaurants() {
    try {
      final query = _firestore
          .collection('restaurants')
          .where('status', isEqualTo: 'verified')
          .orderBy('namaToko');

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => RestaurantModel.fromSnapshot(doc))
            .toList();
      });
    } catch (e) {
      print('Error fetching verified restaurants: $e');
      return Stream.error('Gagal memuat restoran: $e');
    }
  }

  /// Mengambil daftar menu (Future) dari satu restoran spesifik.
  /// Kita batasi (limit) 5 menu untuk ditampilkan di home.
  Future<List<MenuModel>> getMenusForRestaurant(String restoId, {int limit = 5}) {
    try {
      final query = _firestore
          .collection('restaurants')
          .doc(restoId)
          .collection('menus')
          .where('isAvailable', isEqualTo: true) // Hanya menu yang tersedia
          .limit(limit) 
          .get();

      return query.then((snapshot) {
        return snapshot.docs
            .map((doc) => MenuModel.fromSnapshot(doc))
            .toList();
      });
    } catch (e) {
      print('Error fetching menus for restaurant: $e');
      throw Exception('Gagal memuat menu.');
    }
  }
}