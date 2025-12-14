// File: lib/screens/driver/driver_dashboard.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // Wajib ada
import 'package:intl/intl.dart';
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
  
  // --- TAMBAHAN BARU: Image Picker ---
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // --- LOGIKA KAMERA (Commit 3) ---
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
        // Upload bukti & update status
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
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
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
          
          // Loading Overlay (Saat upload foto)
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
    
    // Status Logic
    bool isAssigned = task.status == 'assigned';         // Baru masuk
    bool isReady = task.status == 'ready_for_pickup';    // Siap di Resto
    bool isOnDelivery = task.status == 'on_delivery';    // Sedang Diantar

    // Warna & Teks Dinamis
    Color statusColor;
    Color statusBgColor;
    String statusText;

    if (isOnDelivery) {
      statusColor = Colors.blue[700]!;
      statusBgColor = Colors.blue[50]!;
      statusText = 'SEDANG DIANTAR';
    } else if (isReady) {
      statusColor = Colors.orange[800]!;
      statusBgColor = Colors.orange[50]!;
      statusText = 'SIAP DIAMBIL';
    } else {
      statusColor = Colors.grey[700]!;
      statusBgColor = Colors.grey[200]!;
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
          // --- HEADER: Status & Tanggal ---
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
                Text('$tgl • ${task.mealTime}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- BODY: Timeline UI (Dari Kode Lama Anda) ---
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

                _buildLocationRow(
                  icon: Icons.store_mall_directory,
                  iconColor: Colors.blue,
                  title: 'Ambil di Restoran',
                  subtitle: 'ID Resto: ...${task.restaurantId.length > 5 ? task.restaurantId.substring(0, 5) : task.restaurantId}',
                  isLast: false,
                ),
                _buildLocationRow(
                  icon: Icons.person_pin_circle,
                  iconColor: Colors.red,
                  title: 'Antar ke Pelanggan',
                  subtitle: 'ID User: ...${task.userId.length > 5 ? task.userId.substring(0, 5) : task.userId}',
                  isLast: true,
                ),
              ],
            ),
          ),

          // --- FOOTER: Tombol Aksi (Logic Baru) ---
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
                // Tombol mati jika status 'assigned' (belum ready)
                onPressed: isAssigned ? null : () {
                  if (isReady) {
                    // Klik Mulai Antar
                    _service.startDelivery(task.orderId);
                  } else if (isOnDelivery) {
                    // Klik Selesai -> BUKA KAMERA
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

  // --- WIDGET TIMELINE CANTIK (Dari Kode Lama Anda) ---
  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
  }
}