// File: lib/screens/admin/admin_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/daily_order_model.dart';

class AdminEarningsScreen extends StatelessWidget {
  const AdminEarningsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keuangan Bisnis (Admin)'),
        backgroundColor: Colors.blue[900], 
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('daily_orders')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada transaksi di sistem.'));
          }

          List<DailyOrderModel> allOrders = snapshot.data!.docs
              .map((doc) => DailyOrderModel.fromSnapshot(doc))
              .toList();

          final completedOrders = allOrders
              .where((order) => order.status == 'completed')
              .toList();

          completedOrders.sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));

          // 4. HITUNG-HITUNGAN (MODEL DRIVER KARYAWAN)
          int totalFoodPrice = 0;   
          int totalShippingRevenue = 0; 
          
          for (var order in completedOrders) {
            totalFoodPrice += order.harga;
            totalShippingRevenue += order.shippingCost; 
          }

          // RUMUS PENDAPATAN BARU
          double foodCommission = totalFoodPrice * 0.15; // Komisi NAIK ke 15%
          double totalAdminRevenue = foodCommission + totalShippingRevenue; 
          
          double restaurantShare = totalFoodPrice * 0.85; // Hak Resto turun ke 85%

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- KARTU UTAMA: TOTAL KAS MASUK ---
              _buildSummaryCard(
                title: "Total Pendapatan Bersih",
                subtitle: "(Komisi 15% + Full Ongkir)", // Text diupdate
                amount: currencyFormat.format(totalAdminRevenue),
                color: Colors.blue[800]!,
                icon: Icons.account_balance_wallet,
              ),
              
              const SizedBox(height: 12),
              
              // --- DETAIL SUMBER DANA ---
              Row(
                children: [
                  Expanded(
                    child: _buildSmallCard(
                      title: "Dari Komisi (15%)", // Text diupdate
                      amount: currencyFormat.format(foodCommission),
                      color: Colors.blue[600]!,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSmallCard(
                      title: "Dari Ongkir (100%)",
                      amount: currencyFormat.format(totalShippingRevenue),
                      color: Colors.orange[800]!,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text("Riwayat Pemasukan Kas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),

              // --- LIST RIWAYAT ---
              ...completedOrders.map((order) {
                final tgl = DateFormat('dd MMM, HH:mm').format(order.deliveryDate.toDate());
                final double komisiItem = order.harga * 0.15; // Komisi 15%
                final double totalMasukItem = komisiItem + order.shippingCost;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[50],
                      child: const Icon(Icons.arrow_downward, color: Colors.blue),
                    ),
                    title: Text(order.namaMenu, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$tgl • ID: ...${order.orderId.substring(order.orderId.length - 4)}"),
                        Text("Sumber: Komisi ${currencyFormat.format(komisiItem)} + Ongkir ${currencyFormat.format(order.shippingCost)}", 
                             style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Masuk Kas", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          currencyFormat.format(totalMasukItem), 
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 14)
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              
              if (completedOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text("Belum ada pesanan yang selesai.")),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String subtitle, required String amount, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text(amount, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
          Icon(icon, color: Colors.white24, size: 48),
        ],
      ),
    );
  }

  Widget _buildSmallCard({required String title, required String amount, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(amount, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}