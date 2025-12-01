// File: lib/services/driver_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_order_model.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mengambil daftar tugas yang tersedia (status: 'ready_for_pickup')
  /// Diurutkan berdasarkan tanggal pengiriman (yang paling dekat dulu)
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

  /// Driver mengambil tugas (Update status -> 'on_delivery')
  Future<void> acceptTask(String orderId, String driverId) async {
    try {
      await _firestore.collection('daily_orders').doc(orderId).update({
        'status': 'on_delivery',
        'driverId': driverId, // Simpan ID driver yang mengambil
      });
    } catch (e) {
      print('Error accepting task: $e');
      throw Exception('Gagal mengambil tugas.');
    }
  }

  /// Driver menyelesaikan tugas (Update status -> 'completed')
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