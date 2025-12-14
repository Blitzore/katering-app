// File: lib/services/driver_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart'; // Pastikan package ini ada di pubspec.yaml
import '../models/daily_order_model.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Ganti dengan Cloud Name & Preset milik Anda
  final _cloudinary = CloudinaryPublic('drdfrxobm', 'katering_app', cache: false);

  /// Mengambil tugas driver:
  /// 1. Status 'assigned' (Baru ditugaskan)
  /// 2. Status 'ready_for_pickup' (Sudah dimasak resto, siap ambil)
  /// 3. Status 'on_delivery' (Sedang diantar)
  Stream<List<DailyOrderModel>> getMyTasks(String driverId) {
    return _firestore
        .collection('daily_orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['assigned', 'ready_for_pickup', 'on_delivery']) 
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DailyOrderModel.fromSnapshot(doc))
            .toList());
  }

  /// Mulai pengantaran (Status -> on_delivery)
  Future<void> startDelivery(String orderId) async {
    await _firestore.collection('daily_orders').doc(orderId).update({
      'status': 'on_delivery',
    });
  }

  /// Selesaikan pengantaran DENGAN BUKTI FOTO (Status -> completed)
  Future<void> completeDeliveryWithProof(String orderId, File proofImage) async {
    try {
      // 1. Upload Foto ke Cloudinary
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          proofImage.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'bukti_pengiriman',
          publicId: 'proof_$orderId',
        ),
      );

      // 2. Update Status & Simpan URL Foto
      await _firestore.collection('daily_orders').doc(orderId).update({
        'status': 'completed',
        'proofPhotoUrl': response.secureUrl, // URL dari Cloudinary
      });
    } catch (e) {
      print('Error completing delivery: $e');
      throw Exception('Gagal upload bukti pengiriman.');
    }
  }
}