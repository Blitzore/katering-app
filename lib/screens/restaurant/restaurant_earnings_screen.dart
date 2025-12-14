// File: lib/screens/restaurant/restaurant_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Pastikan package intl sudah ada di pubspec.yaml
import '../../models/daily_order_model.dart';

class RestaurantEarningsScreen extends StatelessWidget {
  const RestaurantEarningsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    // Format mata uang Rupiah
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penghasilan Restoran'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query: Ambil pesanan milik restoran ini yang statusnya 'completed'
        stream: FirebaseFirestore.instance
            .collection('daily_orders')
            .where('restaurantId', isEqualTo: uid)
            .where('status', isEqualTo: 'completed')
            .orderBy('deliveryDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

          final orders = snapshot.data!.docs
              .map((doc) => DailyOrderModel.fromSnapshot(doc))
              .toList();

          // Hitung Total Pendapatan (Omzet Kotor dari Harga Makanan)
          int totalRevenue = 0;
          for (var order in orders) {
            totalRevenue += order.harga;
          }
          
          // Hitung Estimasi Bersih (Dikurangi Komisi Admin 10%)
          double netIncome = totalRevenue * 0.9; 

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
                    const Text('Total Penjualan (Makanan)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(totalRevenue),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const Divider(color: Colors.white30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pesanan Selesai: ${orders.length}', style: const TextStyle(color: Colors.white)),
                        // Info Potongan 10%
                        Text('Est. Bersih (90%): ${currencyFormat.format(netIncome)}', 
                             style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft, 
                  child: Text("Riwayat Transaksi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                ),
              ),

              // --- LIST RIWAYAT ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final tgl = DateFormat('dd MMM yyyy, HH:mm').format(order.deliveryDate.toDate());
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Icon(Icons.check, color: Colors.green[800]),
                        ),
                        title: Text(order.namaMenu, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tgl),
                            if (order.proofPhotoUrl != null)
                              const Text('Bukti Foto Tersedia', style: TextStyle(color: Colors.blue, fontSize: 11)),
                          ],
                        ),
                        trailing: Text(
                          currencyFormat.format(order.harga),
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onTap: () {
                          // Fitur Tambahan: Lihat Bukti Foto jika ada
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