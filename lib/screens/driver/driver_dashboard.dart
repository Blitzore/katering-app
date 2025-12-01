// File: lib/screens/driver/driver_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Background agak abu biar Card menonjol
      appBar: AppBar(
        title: const Text('Tugas Pengantaran'),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: StreamBuilder<List<DailyOrderModel>>(
        stream: _service.getMyTasks(_uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.motorcycle, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada tugas masuk.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const Text(
                    'Istirahat dulu sambil menunggu orderan.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final tasks = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(20), // Padding luar lebih lega
            itemCount: tasks.length,
            separatorBuilder: (ctx, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskCard(task);
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(DailyOrderModel task) {
    final tgl = DateFormat.yMMMd('id_ID').format(task.deliveryDate.toDate());
    final bool isNew = (task.status == 'assigned');

    // Warna status
    final statusColor = isNew ? Colors.blue[700] : Colors.orange[800];
    final statusBgColor = isNew ? Colors.blue[50] : Colors.orange[50];
    final statusText = isNew ? 'BARU MASUK' : 'SEDANG DIANTAR';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '$tgl • ${task.mealTime}',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- BODY: Detail Pengantaran ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama Menu Besar
                Text(
                  task.namaMenu,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                // Alur: Resto -> Customer (Timeline View)
                _buildLocationRow(
                  icon: Icons.store_mall_directory,
                  iconColor: Colors.blue,
                  title: 'Ambil di Restoran',
                  subtitle: 'ID: ...${task.restaurantId.substring(0, 5)}',
                  isLast: false,
                ),
                _buildLocationRow(
                  icon: Icons.person_pin_circle,
                  iconColor: Colors.red,
                  title: 'Antar ke Pelanggan',
                  subtitle: 'ID: ...${task.userId.substring(0, 5)}',
                  isLast: true,
                ),
              ],
            ),
          ),

          // --- FOOTER: Tombol Aksi ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isNew ? Theme.of(context).primaryColor : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (isNew) {
                    _service.startDelivery(task.id);
                  } else {
                    _service.completeDelivery(task.id);
                  }
                },
                child: Text(
                  isNew ? 'MULAI PENGANTARAN' : 'SELESAIKAN TUGAS',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget untuk membuat tampilan timeline lokasi
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
          // Kolom Ikon & Garis
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
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
                const SizedBox(height: 6), // Menyejajarkan teks dengan ikon
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 24), // Jarak ke item berikutnya
              ],
            ),
          ),
        ],
      ),
    );
  }
}