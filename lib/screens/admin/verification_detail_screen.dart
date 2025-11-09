// File: lib/screens/admin/verification_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

/// Menampilkan detail data pendaftar dan tombol aksi (Approve/Reject).
class VerificationDetailScreen extends StatefulWidget {
  final String collection;
  final String uid;
  final Map<String, dynamic> data;

  const VerificationDetailScreen({
    super.key,
    required this.collection,
    required this.uid,
    required this.data,
  });

  @override
  _VerificationDetailScreenState createState() =>
      _VerificationDetailScreenState();
}

class _VerificationDetailScreenState extends State<VerificationDetailScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = false;

  /// Menangani aksi update status
  Future<void> _handleUpdateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await _adminService.updatePartnerStatus(
        collection: widget.collection,
        uid: widget.uid,
        newStatus: newStatus,
      );

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Mitra berhasil di-$newStatus!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Kembali ke halaman list
      navigator.pop(); 

    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Helper untuk format camelCase (contoh: 'namaLengkap')
  /// menjadi Title Case (contoh: 'Nama Lengkap')
  String _formatKey(String key) {
    if (key.isEmpty) return '';
    // Menambahkan spasi sebelum huruf kapital
    String spaced = key.replaceAllMapped(
        RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}');
    // Kapitalisasi huruf pertama
    return spaced[0].toUpperCase() + spaced.substring(1);
  }


  @override
  Widget build(BuildContext context) {
    // Menentukan judul berdasarkan koleksi
    final title = widget.collection == 'restaurants'
        ? 'Detail Restoran'
        : 'Detail Driver';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logika Tampilan Kustom
                // Tampilkan detail Driver atau Restoran
                if (widget.collection == 'drivers')
                  _buildDriverDetails(context)
                else
                  _buildRestaurantDetails(context),
                
                const SizedBox(height: 100), // Spacer untuk tombol
              ],
            ),
          ),
          // Tombol Aksi (Sticky di bawah)
          if (_isLoading)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            )
          else
            _buildActionButtons(context),
        ],
      ),
    );
  }

  /// Widget Kustom untuk menampilkan detail DRIVER sesuai urutan
  Widget _buildDriverDetails(BuildContext context) {
    /// Urutan field yang Anda inginkan (Email dipindah ke atas)
    const fieldOrder = [
      'email', // <-- DIPINDAH KE ATAS
      'namaLengkap',
      'noHp',
      'noPolisi',
      'ktpUrl', // Foto KTP
      'simUrl', // Foto SIM
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fieldOrder
          .where((key) => widget.data.containsKey(key)) // Cek jika data ada
          .map((key) => _buildDetailRow(
                context,
                key,
                widget.data[key].toString(),
              ))
          .toList(),
    );
  }

  /// Widget Kustom untuk menampilkan detail RESTORAN + Menu
  Widget _buildRestaurantDetails(BuildContext context) {
     /// Urutan field yang Anda inginkan (Email dipindah ke atas)
     const fieldOrder = [
      'email', // <-- DIPINDAH KE ATAS
      'namaToko',
      'alamat',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tampilkan data utama restoran
        ...fieldOrder
            .where((key) => widget.data.containsKey(key))
            .map((key) => _buildDetailRow(
                  context,
                  key,
                  widget.data[key].toString(),
                ))
            ,
        
        // Tambahkan pemisah dan list menu
        const SizedBox(height: 16),
        Text(
          'Menu yang Didaftarkan',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Divider(),
        _MenuReviewList(restoId: widget.uid),
      ],
    );
  }


  /// Helper untuk menampilkan baris data (Key-Value)
  Widget _buildDetailRow(BuildContext context, String key, String value) {
    // Gunakan helper format yang baru
    final displayKey = _formatKey(key);

    // Jika value adalah URL gambar, tampilkan sebagai gambar
    if (value.startsWith('http') &&
        (value.contains('cloudinary') ||
            value.endsWith('.jpg') ||
            value.endsWith('.png'))) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayKey, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                value,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  return progress == null
                      ? child
                      : Container(
                          height: 100,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()));
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: Colors.grey[200],
                    child: const Center(
                        child: Icon(Icons.broken_image, size: 40)),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayKey, style: Theme.of(context).textTheme.titleSmall),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
          const Divider(),
        ],
      ),
    );
  }

  /// Helper untuk membangun tombol aksi Approve/Reject
  Widget _buildActionButtons(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), // Padding bawah
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Tolak'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => _handleUpdateStatus('rejected'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Setujui'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => _handleUpdateStatus('verified'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Widget baru untuk mengambil dan menampilkan daftar menu restoran
class _MenuReviewList extends StatelessWidget {
  final String restoId;
  const _MenuReviewList({super.key, required this.restoId});

  @override
  Widget build(BuildContext context) {
    /// Query ke subkoleksi 'menus'
    final menuStream = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restoId)
        .collection('menus')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: menuStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text(
            'Gagal memuat menu.',
            style: TextStyle(color: Colors.red),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('Restoran ini belum mendaftarkan menu.');
        }

        final menuDocs = snapshot.data!.docs;

        /// Gunakan Column, bukan ListView (karena sudah di dalam SingleChildScrollView)
        return Column(
          children: menuDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    data['fotoUrl'] ?? '',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
                title: Text(data['namaMenu'] ?? 'Nama Menu'),
                subtitle: Text('Rp ${data['harga'] ?? 0}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}