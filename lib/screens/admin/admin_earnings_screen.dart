// File: lib/screens/admin/admin_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/daily_order_model.dart';

class AdminEarningsScreen extends StatelessWidget {
  const AdminEarningsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format Rupiah
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendapatan Platform'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Ambil SEMUA order selesai dari seluruh restoran
        stream: FirebaseFirestore.instance
            .collection('daily_orders')
            .where('status', isEqualTo: 'completed')
            .orderBy('deliveryDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada transaksi selesai.'));
          }

          final allOrders = snapshot.data!.docs
              .map((doc) => DailyOrderModel.fromSnapshot(doc))
              .toList();

          // --- HITUNG PENDAPATAN ADMIN ---
          double totalAdminRevenue = 0;
          double totalFoodCommission = 0;
          int totalShippingRevenue = 0;

          for (var order in allOrders) {
            // 1. Komisi 10% dari Harga Makanan
            double commission = order.harga * 0.10;
            
            // 2. 100% Ongkir Masuk Admin
            int shipping = order.shippingCost; 

            totalFoodCommission += commission;
            totalShippingRevenue += shipping;
            totalAdminRevenue += (commission + shipping);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // KARTU TOTAL
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.purple.shade400]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    const Text('Total Pendapatan Bersih', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      currency.format(totalAdminRevenue),
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const Divider(color: Colors.white30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Komisi (10%)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(currency.format(totalFoodCommission), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Ongkir (100%)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(currency.format(totalShippingRevenue), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              const Text("Riwayat Pemasukan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),

              // LIST RIWAYAT
              ...allOrders.map((order) {
                double myCut = (order.harga * 0.10) + order.shippingCost;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple[100],
                      child: Icon(Icons.attach_money, color: Colors.purple[800]),
                    ),
                    title: Text(order.namaMenu),
                    subtitle: Text('Makanan: ${currency.format(order.harga)} | Ongkir: ${currency.format(order.shippingCost)}'),
                    trailing: Text(
                      '+ ${currency.format(myCut)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}