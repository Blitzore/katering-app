// File: lib/services/customer_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_model.dart';
import '../models/restaurant_model.dart';
import '../models/daily_order_model.dart';

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// [BARU MINGGU 8]
  /// Mengambil detail satu restoran berdasarkan ID.
  /// Digunakan di Checkout untuk mengecek lokasi restoran sebelum hitung ongkir.
  Future<RestaurantModel?> getRestaurantById(String restoId) async {
    try {
      final doc = await _firestore.collection('restaurants').doc(restoId).get();
      if (doc.exists) {
        return RestaurantModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      print('Error get restaurant by ID: $e');
      return null;
    }
  }

  /// Mengambil daftar semua restoran yang statusnya 'verified'.
  /// Digunakan di Halaman Utama (Home).
  Stream<List<RestaurantModel>> getVerifiedRestaurants() {
    try {
      return _firestore
          .collection('restaurants')
          .where('status', isEqualTo: 'verified')
          .orderBy('namaToko')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => RestaurantModel.fromSnapshot(doc))
            .toList();
      });
    } catch (e) {
      print('Error fetching verified restaurants: $e');
      return Stream.error('Gagal memuat restoran: $e');
    }
  }

  /// Mengambil daftar menu dari restoran tertentu.
  /// Digunakan di Halaman Utama untuk menampilkan preview menu.
  Future<List<MenuModel>> getMenusForRestaurant(String restoId, {int limit = 5}) {
    try {
      return _firestore
          .collection('restaurants')
          .doc(restoId)
          .collection('menus')
          .where('isAvailable', isEqualTo: true)
          .limit(limit)
          .get()
          .then((snapshot) {
        return snapshot.docs
            .map((doc) => MenuModel.fromSnapshot(doc))
            .toList();
      });
    } catch (e) {
      print('Error fetching menus: $e');
      throw Exception('Gagal memuat menu.');
    }
  }

  /// Mengambil riwayat pesanan milik user yang sedang login.
  /// Digunakan di halaman 'Pesanan Saya'.
  Stream<List<DailyOrderModel>> getMyOrders(String userId) {
    try {
      return _firestore
          .collection('daily_orders')
          .where('userId', isEqualTo: userId)
          .orderBy('deliveryDate', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => DailyOrderModel.fromSnapshot(doc))
            .toList();
      });
    } catch (e) {
      print('Error fetching my orders: $e');
      return Stream.error('Gagal memuat pesanan: $e');
    }
  }
}