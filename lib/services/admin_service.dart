// File: lib/services/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service untuk menangani logika bisnis terkait Admin.
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Memperbarui status mitra (restoran atau driver).
  ///
  /// [collection]: Nama koleksi ('restaurants' atau 'drivers')
  /// [uid]: User ID (dokumen ID) dari mitra
  /// [newStatus]: Status baru ('verified' atau 'rejected')
  Future<void> updatePartnerStatus({
    required String collection,
    required String uid,
    required String newStatus,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(uid)
          .update({'status': newStatus});
    } catch (e) {
      // Menangani error jika terjadi
      print('Error updating partner status: $e');
      throw Exception('Gagal memperbarui status mitra.');
    }
  }
}