// File: lib/screens/customer/my_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/daily_order_model.dart';
import '../../services/customer_service.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final CustomerService _service = CustomerService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pesanan Saya'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Berjalan'),
              Tab(text: 'Riwayat'),
            ],
          ),
        ),
        body: StreamBuilder<List<DailyOrderModel>>(
          stream: _service.getMyOrders(_uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}\n(Cek Index Firestore)'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Belum ada riwayat pesanan.'));
            }

            final allOrders = snapshot.data!;
            
            // Filter: Pisahkan yang aktif dan selesai
            final activeOrders = allOrders.where((o) => o.status != 'completed' && o.status != 'cancelled').toList();
            final historyOrders = allOrders.where((o) => o.status == 'completed' || o.status == 'cancelled').toList();

            return TabBarView(
              children: [
                _OrderList(orders: activeOrders, isActive: true),
                _OrderList(orders: historyOrders, isActive: false),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<DailyOrderModel> orders;
  final bool isActive;

  const _OrderList({Key? key, required this.orders, required this.isActive}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          isActive ? 'Tidak ada pesanan aktif.' : 'Belum ada riwayat selesai.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final tgl = DateFormat.yMMMd('id_ID').format(order.deliveryDate.toDate());
        
        // Tentukan warna dan teks status
        Color statusColor = Colors.grey;
        String statusText = order.status.toUpperCase();
        
        switch (order.status) {
          case 'confirmed':
            statusColor = Colors.blue;
            statusText = 'MENUNGGU RESTO';
            break;
          case 'assigned': 
            // Pelanggan melihat "Assigned" sebagai "Diproses"
            statusColor = Colors.orange;
            statusText = 'DIPROSES';
            break;
          case 'ready_for_pickup':
            statusColor = Colors.orange;
            statusText = 'SIAP DIAMBIL';
            break;
          case 'on_delivery':
            statusColor = Colors.purple;
            statusText = 'SEDANG DIANTAR';
            break;
          case 'completed':
            statusColor = Colors.green;
            statusText = 'SELESAI';
            break;
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                order.fotoUrl,
                width: 50, height: 50, fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.fastfood),
              ),
            ),
            title: Text(order.namaMenu, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('$tgl - ${order.mealTime}'),
                if (isActive) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                ]
              ],
            ),
            trailing: isActive 
              ? const Icon(Icons.access_time, color: Colors.blue) 
              : const Icon(Icons.check_circle, color: Colors.green),
          ),
        );
      },
    );
  }
}