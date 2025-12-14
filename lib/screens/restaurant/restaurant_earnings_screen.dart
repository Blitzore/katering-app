// File: lib/screens/restaurant/restaurant_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 
import '../../models/daily_order_model.dart';

class RestaurantEarningsScreen extends StatelessWidget {
  const RestaurantEarningsScreen({Key? key}) : super(key: key);

  // Catatan: Fungsi _buildSummaryRow sudah dihapus karena tidak digunakan di sini.

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penghasilan Restoran'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('daily_orders')
            .where('restaurantId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          List<DailyOrderModel> allOrders = [];
          if (snapshot.hasData) {
            allOrders = snapshot.data!.docs
                .map((doc) => DailyOrderModel.fromSnapshot(doc))
                .toList();
          }

          // Filter Manual: Hanya ambil yang 'completed'
          final completedOrders = allOrders
              .where((order) => order.status == 'completed')
              .toList();

          completedOrders.sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));

          // Hitung Total Pendapatan Kotor
          int totalRevenue = 0;
          for (var order in completedOrders) {
            totalRevenue += order.harga;
          }
          
          // Hitung Estimasi Bersih (Dipotong Komisi 15% / Sisa 85%)
          double netIncome = totalRevenue * 0.85; 
          double totalCommission = totalRevenue * 0.15; // Komisi Admin

          if (completedOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monetization_on_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('Belum ada pesanan selesai.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return Column(
            children: [
              // --- KARTU RINGKASAN ---
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade400]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  children: [
                    const Text('Total Omzet Makanan', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(totalRevenue),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const Divider(color: Colors.white30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pesanan Selesai: ${completedOrders.length}', style: const TextStyle(color: Colors.white)),
                        // Tampilkan potongan dan bersih
                        Text('Potongan (15%): ${currencyFormat.format(totalCommission)}', 
                             style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                       child: Text('Estimasi Bersih (85%): ${currencyFormat.format(netIncome)}', 
                             style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft, 
                  child: Text("Riwayat Pembayaran Bersih", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                ),
              ),

              // --- LIST RIWAYAT ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: completedOrders.length,
                  itemBuilder: (context, index) {
                    final order = completedOrders[index];
                    final tgl = DateFormat('dd MMM yyyy, HH:mm').format(order.deliveryDate.toDate());
                    final double bersihPerOrder = order.harga * 0.85; // Bersih per order 85%
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Icon(Icons.check_circle, color: Colors.green[800]),
                        ),
                        title: Text(order.namaMenu, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tgl),
                            Text('Potongan Admin: ${currencyFormat.format(order.harga * 0.15)}', style: const TextStyle(color: Colors.red, fontSize: 11)),
                            if (order.proofPhotoUrl != null)
                              const Text('Bukti Foto Tersedia', style: TextStyle(color: Colors.blue, fontSize: 11)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("Diterima", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text(
                              currencyFormat.format(bersihPerOrder),
                              style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (order.proofPhotoUrl != null) {
                            showDialog(
                              context: context,
                              builder: (ctx) => Dialog(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.network(order.proofPhotoUrl!),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx), 
                                      child: const Text('Tutup')
                                    )
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}