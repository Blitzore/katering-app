// File: lib/screens/admin/admin_manage_drivers.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart'; // WAJIB: Import ini untuk tipe data LatLng
import '../maps/location_picker_screen.dart'; // WAJIB: Arahkan ke folder maps

class AdminManageDriversScreen extends StatelessWidget {
  const AdminManageDriversScreen({Key? key}) : super(key: key);

  /// Fungsi untuk membuka peta & update lokasi driver
  Future<void> _pickDriverLocation(BuildContext context, String driverId, String currentName) async {
    // Buka Peta OpenStreetMap
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(
          isSelecting: true, // Mode memilih (agar muncul pin & tombol pilih)
        ),
      ),
    );

    // Jika Admin sudah memilih lokasi dan menekan tombol pilih
    if (result != null) {
      // Simpan koordinat ke Firestore Drivers
      await FirebaseFirestore.instance.collection('drivers').doc(driverId).update({
        'latitude': result.latitude,
        'longitude': result.longitude,
      });

      // Tampilkan notifikasi sukses
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lokasi mangkal $currentName berhasil diupdate!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Lokasi Driver'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Ambil hanya driver yang statusnya verified
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .where('status', isEqualTo: 'verified')
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // 2. Error State
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // 3. Empty State
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.motorcycle, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada driver terverifikasi.'),
                ],
              ),
            );
          }

          final drivers = snapshot.data!.docs;

          // 4. List Driver
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final data = drivers[index].data() as Map<String, dynamic>;
              final driverId = drivers[index].id;
              final name = data['namaLengkap'] ?? 'Driver Tanpa Nama';
              
              // Cek apakah lokasi sudah diatur di database
              final double? lat = data['latitude'];
              final bool hasLocation = (lat != null && lat != 0.0);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: hasLocation ? Colors.green : Colors.grey,
                    radius: 25,
                    child: const Icon(Icons.motorcycle, color: Colors.white),
                  ),
                  title: Text(
                    name, 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            hasLocation ? Icons.check_circle : Icons.warning_amber_rounded,
                            size: 14,
                            color: hasLocation ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasLocation ? 'Lokasi Aktif' : 'Belum set lokasi',
                            style: TextStyle(
                              color: hasLocation ? Colors.green[700] : Colors.orange[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_location_alt, color: Colors.blue, size: 30),
                    tooltip: 'Atur Lokasi Mangkal',
                    onPressed: () => _pickDriverLocation(context, driverId, name),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}