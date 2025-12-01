// File: lib/services/driver_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_order_model.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 1. Mengambil tugas BARU yang tersedia di sistem
  /// (Status: 'ready_for_pickup')
  Stream<List<DailyOrderModel>> getAvailableTasks() {
    try {
      final query = _firestore
          .collection('daily_orders')
          .where('status', isEqualTo: 'ready_for_pickup')
          .orderBy('deliveryDate', descending: false);

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => DailyOrderModel.fromSnapshot(doc))
            .toList();
      });
    } catch (e) {
      print('Error fetching available tasks: $e');
      return Stream.error('Gagal memuat tugas: $e');
    }
  }

  /// 2. Mengambil tugas AKTIF milik driver tertentu
  /// (Status: 'on_delivery' DAN driverId == id_driver_login)
  Stream<List<DailyOrderModel>> getActiveTasks(String driverId) {
    try {
      final query = _firestore
          .collection('daily_orders')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'on_delivery')
          .orderBy('deliveryDate', descending: false);

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => DailyOrderModel.fromSnapshot(doc))
            .toList();
      });
    } catch (e) {
      print('Error fetching active tasks: $e');
      return Stream.error('Gagal memuat tugas aktif: $e');
    }
  }

  /// 3. Aksi: Driver mengambil tugas
  Future<void> acceptTask(String orderId, String driverId) async {
    try {
      await _firestore.collection('daily_orders').doc(orderId).update({
        'status': 'on_delivery',
        'driverId': driverId,
      });
    } catch (e) {
      print('Error accepting task: $e');
      throw Exception('Gagal mengambil tugas.');
    }
  }

  /// 4. Aksi: Driver menyelesaikan tugas
  Future<void> completeTask(String orderId) async {
    try {
      await _firestore.collection('daily_orders').doc(orderId).update({
        'status': 'completed',
      });
    } catch (e) {
      print('Error completing task: $e');
      throw Exception('Gagal menyelesaikan tugas.');
    }
  }
}