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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Driver'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tugas Baru', icon: Icon(Icons.new_releases)),
              Tab(text: 'Sedang Diantar', icon: Icon(Icons.motorcycle)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            )
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Daftar tugas yang tersedia (ready_for_pickup)
            _TaskList(
              stream: _driverService.getAvailableTasks(),
              isAvailableTab: true,
              driverId: _driverId,
              service: _driverService,
            ),
            // Tab 2: Daftar tugas yang sedang diambil driver ini (on_delivery)
            _TaskList(
              stream: _driverService.getActiveTasks(_driverId),
              isAvailableTab: false,
              driverId: _driverId,
              service: _driverService,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final Stream<List<DailyOrderModel>> stream;
  final bool isAvailableTab;
  final String driverId;
  final DriverService service;

  const _TaskList({
    Key? key,
    required this.stream,
    required this.isAvailableTab,
    required this.driverId,
    required this.service,
  }) : super(key: key);

  Future<void> _handleAction(BuildContext context, String orderId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      if (isAvailableTab) {
        // Aksi: Ambil Tugas
        await service.acceptTask(orderId, driverId);
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Tugas diambil! Lanjut ke tab "Sedang Diantar".'), backgroundColor: Colors.green));
      } else {
        // Aksi: Selesai Antar
        await service.completeTask(orderId);
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Tugas Selesai! Saldo Anda akan bertambah.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DailyOrderModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error (Cek Index): ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              isAvailableTab
                  ? 'Tidak ada tugas baru saat ini.'
                  : 'Anda sedang tidak mengantar pesanan.',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        final tasks = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final tglKirim = DateFormat.yMMMd('id_ID').format(task.deliveryDate.toDate());

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Text(task.namaMenu, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    // Tampilkan alamat sederhana (ID)
                    Text('📍 Resto: ${task.restaurantId.substring(0,5)}...'),
                    Text('🏠 Tujuan: ${task.userId.substring(0,5)}...'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAvailableTab ? Theme.of(context).primaryColor : Colors.orange,
                        ),
                        onPressed: () => _handleAction(context, task.id),
                        child: Text(isAvailableTab ? 'AMBIL TUGAS' : 'SELESAI ANTAR'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}