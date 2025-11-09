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
      // Buat WriteBatch untuk multi-update
      final batch = _firestore.batch();

      // 1. Update dokumen utama (restaurant atau driver)
      final docRef = _firestore.collection(collection).doc(uid);
      batch.update(docRef, {'status': newStatus});

      // 2. JIKA ini adalah 'restaurants', update juga semua subkoleksi 'menus'
      if (collection == 'restaurants') {
        // Ambil semua dokumen 'menus' di bawah restoran ini
        final menuQuery = await _firestore
            .collection(collection)
            .doc(uid)
            .collection('menus')
            .get();
            
        // Loop dan tambahkan update ke batch
        for (final doc in menuQuery.docs) {
          batch.update(doc.reference, {'statusResto': newStatus});
        }
      }
      
      // 3. Commit semua perubahan sekaligus
      await batch.commit();

    } catch (e) {
      print('Error updating partner status: $e');
      throw Exception('Gagal memperbarui status mitra.');
    }
  }
}