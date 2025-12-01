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
  final DriverService _driverService = DriverService();
  final String _driverId = FirebaseAuth.instance.currentUser!.uid;
  late Stream<List<DailyOrderModel>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _tasksStream = _driverService.getAvailableTasks();
  }

  /// Menangani tombol "Ambil Tugas"
  Future<void> _handleAcceptTask(String orderId) async {
    try {
      await _driverService.acceptTask(orderId, _driverId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugas berhasil diambil!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas Pengantaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: StreamBuilder<List<DailyOrderModel>>(
        stream: _tasksStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada pesanan yang siap diantar.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final tasks = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
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
    final String tglKirim = DateFormat.yMMMd('id_ID').format(task.deliveryDate.toDate());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Waktu & Tanggal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(task.mealTime, style: const TextStyle(color: Colors.white)),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                Text(tglKirim, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Detail Menu
            Text(
              task.namaMenu,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            
            // Info Lokasi (Sederhana dulu)
            Row(
              children: [
                const Icon(Icons.store, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Ambil di Restoran (ID: ${task.restaurantId.substring(0, 5)}...)')),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Antar ke Pelanggan (ID: ${task.userId.substring(0, 5)}...)')),
              ],
            ),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleAcceptTask(task.id),
                child: const Text('Ambil Tugas Ini'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}