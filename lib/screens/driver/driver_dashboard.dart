// File: lib/screens/driver/driver_dashboard.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Wajib untuk ambil lokasi
import 'package:url_launcher/url_launcher.dart'; // Wajib untuk buka Google Maps

import '../../models/daily_order_model.dart';
import '../../services/driver_service.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({Key? key}) : super(key: key);

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final DriverService _service = DriverService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // --- LOGIKA BUKA GOOGLE MAPS (BARU) ---
  Future<void> _openMap(String collection, String docId) async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil data Lat/Lng dari Firestore berdasarkan ID
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection(collection).doc(docId).get();
      
      if (!doc.exists) throw "Data lokasi tidak ditemukan.";
      
      final data = doc.data() as Map<String, dynamic>;
      // Pastikan field di database Anda bernama 'latitude' dan 'longitude'
      double? lat = data['latitude'];
      double? lng = data['longitude'];

      if (lat == null || lng == null) throw "Koordinat belum diatur oleh user/resto.";

      // 2. Buka Google Maps
      final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng");
      
      if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
        throw "Tidak bisa membuka aplikasi Peta.";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Map: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA KAMERA ---
  Future<void> _handleCompleteTask(String orderId) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Ambil Foto (Kamera)'),
            onTap: () async {
              Navigator.pop(ctx);
              _processImage(orderId, ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Pilih dari Galeri'),
            onTap: () async {
              Navigator.pop(ctx);
              _processImage(orderId, ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _processImage(String orderId, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
    
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        File imageFile = File(pickedFile.path);
        await _service.completeDeliveryWithProof(orderId, imageFile);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tugas Selesai! Bukti terupload.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tugas Pengantaran'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<DailyOrderModel>>(
            stream: _service.getMyTasks(_uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.motorcycle, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Belum ada tugas masuk.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }

              final tasks = snapshot.data!;
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: tasks.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildTaskCard(tasks[index]);
                },
              );
            },
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DailyOrderModel task) {
    final tgl = DateFormat.yMMMd('id_ID').format(task.deliveryDate.toDate());
    
    bool isAssigned = task.status == 'assigned';         
    bool isReady = task.status == 'ready_for_pickup';    
    bool isOnDelivery = task.status == 'on_delivery';    

    Color statusColor;
    Color statusBgColor;
    String statusText;

    if (isOnDelivery) {
      statusColor = Colors.blue[700]!;
      statusBgColor = Colors.blue[50]!;
      statusText = 'SEDANG DIANTAR';
    } else if (isReady) {
      statusColor = Colors.green[800]!;
      statusBgColor = Colors.green[50]!;
      statusText = 'SIAP DIAMBIL';
    } else {
      statusColor = Colors.orange[800]!;
      statusBgColor = Colors.orange[50]!;
      statusText = 'MENUNGGU RESTO';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$tgl • ${task.mealTime}', 
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body Timeline
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.namaMenu,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 20),

                // --- UPDATE: Tambahkan parameter onMapTap ---
                _buildLocationRow(
                  icon: Icons.store_mall_directory,
                  iconColor: Colors.blue,
                  title: 'Ambil di Restoran',
                  subtitle: 'Klik ikon map untuk navigasi',
                  isLast: false,
                  onMapTap: () {
                    // Buka Map Restoran (Collection: restaurants)
                    _openMap('restaurants', task.restaurantId);
                  },
                ),
                _buildLocationRow(
                  icon: Icons.person_pin_circle,
                  iconColor: Colors.red,
                  title: 'Antar ke Pelanggan',
                  subtitle: 'Klik ikon map untuk navigasi',
                  isLast: true,
                  onMapTap: () {
                    // Buka Map User (Collection: users)
                    // Asumsi: Data user ada di collection 'users'
                    _openMap('users', task.userId);
                  },
                ),
              ],
            ),
          ),

          // Footer Tombol
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnDelivery ? Colors.green : (isReady ? Theme.of(context).primaryColor : Colors.grey),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: isAssigned ? null : () {
                  if (isReady) {
                    _service.startDelivery(task.orderId);
                  } else if (isOnDelivery) {
                    _handleCompleteTask(task.orderId);
                  }
                },
                child: Text(
                  isAssigned 
                    ? 'MENUNGGU RESTO...' 
                    : (isReady ? 'MULAI PENGANTARAN' : 'SELESAIKAN & UPLOAD BUKTI'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET TIMELINE DIPERBARUI DENGAN TOMBOL MAP ---
  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLast,
    required VoidCallback onMapTap, // Tambahan parameter
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kolom Icon & Garis
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey[200],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          
          // Kolom Teks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // --- TOMBOL MAP (BARU) ---
          IconButton(
            onPressed: onMapTap, 
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!)
              ),
              child: const Icon(Icons.map_outlined, color: Colors.blue, size: 20),
            ),
            tooltip: "Buka Peta",
          ),
        ],
      ),
    );
  }
}