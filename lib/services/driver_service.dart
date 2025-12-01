// File: lib/services/driver_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_order_model.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mengambil SEMUA tugas yang ditugaskan ke driver ini (assigned/on_delivery)
  Stream<List<DailyOrderModel>> getMyTasks(String driverId) {
    try {
      final query = _firestore
          .collection('daily_orders')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['assigned', 'on_delivery'])
          .orderBy('deliveryDate');

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => DailyOrderModel.fromSnapshot(doc))
            .toList();
      });
    } catch (e) {
      print('Error fetching driver tasks: $e');
      return Stream.error('Gagal memuat tugas: $e');
    }
  }

  /// Driver Klik "Mulai Pengantaran"
  Future<void> startDelivery(String orderId) async {
    try {
      await _firestore.collection('daily_orders').doc(orderId).update({
        'status': 'on_delivery',
      });
    } catch (e) {
      throw Exception('Gagal memulai pengantaran: $e');
    }
  }

  /// Driver Klik "Selesai"
  Future<void> completeDelivery(String orderId) async {
    try {
      await _firestore.collection('daily_orders').doc(orderId).update({
        'status': 'completed',
      });
    } catch (e) {
      throw Exception('Gagal menyelesaikan tugas: $e');
    }
  }
}