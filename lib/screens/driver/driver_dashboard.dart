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
      appBar: AppBar(
        title: const Text('Tugas Saya'),
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
              child: Text(
                'Error: ${snapshot.error}\n(Pastikan Index Driver sudah dibuat)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada tugas dari Admin/Sistem.',
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
    final tgl = DateFormat.yMMMd('id_ID').format(task.deliveryDate.toDate());
    final bool isNew = (task.status == 'assigned');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isNew ? Colors.blue : Colors.orange, 
          width: 2
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    isNew ? 'BARU MASUK' : 'SEDANG DIANTAR', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                  backgroundColor: isNew ? Colors.blue : Colors.orange,
                ),
                Text('$tgl - ${task.mealTime}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.namaMenu, 
              style: Theme.of(context).textTheme.titleLarge
            ),
            const SizedBox(height: 8),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.store, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text('Ambil: Resto ID ...${task.restaurantId.substring(0,5)}')),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text('Antar: Pelanggan ...${task.userId.substring(0,5)}')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isNew ? Colors.blue : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
          ],
        ),
      ),
    );
  }
}