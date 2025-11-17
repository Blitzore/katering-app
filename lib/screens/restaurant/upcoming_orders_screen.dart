// File: lib/screens/restaurant/upcoming_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/daily_order_model.dart';
import '../../services/restaurant_service.dart'; 

/// Halaman untuk menampilkan pesanan mendatang (10 hari)
class UpcomingOrdersScreen extends StatefulWidget { // <-- NAMA CLASS DIUBAH
  const UpcomingOrdersScreen({Key? key}) : super(key: key);

  @override
  State<UpcomingOrdersScreen> createState() => _UpcomingOrdersScreenState();
}

class _UpcomingOrdersScreenState extends State<UpcomingOrdersScreen> { // <-- NAMA CLASS DIUBAH
  late Stream<List<DailyOrderModel>> _ordersStream;
  final String _restoId = FirebaseAuth.instance.currentUser!.uid;
  final RestaurantService _service = RestaurantService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ordersStream = _fetchUpcomingOrders();
  }

  /// Mendapatkan timestamp awal hari (00:00:00)
  Timestamp _getStartOfToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return Timestamp.fromDate(startOfDay);
  }
  
  /// Mendapatkan timestamp 10 hari dari sekarang (23:59:59)
  Timestamp _getEndOf10Days() {
    final now = DateTime.now();
    // Tambah 9 hari ke hari ini (karena hari ini adalah hari ke-1)
    final endOf10Days = DateTime(now.year, now.month, now.day + 9, 23, 59, 59);
    return Timestamp.fromDate(endOf10Days);
  }

  /// Query untuk mengambil pesanan 10 hari ke depan
  Stream<List<DailyOrderModel>> _fetchUpcomingOrders() {
    final startOfToday = _getStartOfToday();
    final endOf10Days = _getEndOf10Days(); 

    final query = FirebaseFirestore.instance
        .collection('daily_orders')
        .where('restaurantId', isEqualTo: _restoId)
        .where('status', isEqualTo: 'confirmed') 
        .where('deliveryDate', isGreaterThanOrEqualTo: startOfToday)
        .where('deliveryDate', isLessThanOrEqualTo: endOf10Days)
        .orderBy('deliveryDate', descending: false); 

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => DailyOrderModel.fromSnapshot(doc))
          .toList();
    });
  }

  /// Menangani penekanan tombol "Tandai Siap Diambil"
  Future<void> _handleMarkAsReady(List<DailyOrderModel> batchOrders) async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Ambil semua ID dari batch
    final orderIds = batchOrders.map((order) => order.id).toList();

    try {
      await _service.updateOrderStatusBatch(orderIds, 'ready_for_pickup');
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${orderIds.length} pesanan ditandai siap diambil.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Mendatang (10 Hari)'),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<DailyOrderModel>>(
            stream: _ordersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                print(snapshot.error);
                return const Center(
                  child: Text('Error memuat pesanan. (Pastikan Index sudah dibuat)'),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Tidak ada pesanan mendatang.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final orders = snapshot.data!;
              
              // --- [LOGIKA PENGELOMPOKAN (GROUPING) BARU] ---
              final Map<String, List<DailyOrderModel>> groupedOrders = {};
              
              for (final order in orders) {
                // Buat kunci unik untuk setiap batch (tanggal + waktu makan)
                String dateKey = DateFormat('yyyy-MM-dd').format(order.deliveryDate.toDate());
                String groupKey = '$dateKey-${order.mealTime}';
                
                if (!groupedOrders.containsKey(groupKey)) {
                  groupedOrders[groupKey] = [];
                }
                groupedOrders[groupKey]!.add(order);
              }
              
              // Ubah Map menjadi List untuk ditampilkan
              final groupKeys = groupedOrders.keys.toList();

              return ListView.builder(
                itemCount: groupKeys.length,
                itemBuilder: (context, index) {
                  final key = groupKeys[index];
                  final batchOrders = groupedOrders[key]!;
                  return _buildBatchCard(context, key, batchOrders);
                },
              );
            },
          ),
          // Tampilkan loading overlay jika sedang memproses
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  /// Widget untuk menampilkan SATU KELOMPOK (BATCH) pesanan
  Widget _buildBatchCard(BuildContext context, String groupKey, List<DailyOrderModel> batchOrders) {
    // Ambil data dari item pertama (karena semuanya sama)
    final deliveryDate = batchOrders.first.deliveryDate.toDate();
    final mealTime = batchOrders.first.mealTime;
    final tglKirim = DateFormat.yMMMd('id_ID').format(deliveryDate);

    // --- [LOGIKA TOMBOL HARI INI] ---
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deliveryDay = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
    
    // Tombol hanya aktif jika tanggal pengiriman adalah hari ini
    final bool isToday = deliveryDay.isAtSameMomentAs(today);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. JUDUL BATCH
          ListTile(
            title: Text('$tglKirim - $mealTime', style: Theme.of(context).textTheme.titleLarge),
            subtitle: Text('Total ${batchOrders.length} menu untuk disiapkan.'),
            tileColor: (isToday ? Colors.green[50] : Colors.grey[100]),
          ),
          
          // 2. DAFTAR MENU DALAM BATCH
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: batchOrders.map((order) {
                // Tampilkan setiap menu dalam batch
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: Image.network(
                          order.fotoUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          order.namaMenu,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          // 3. TOMBOL AKSI (BATCH)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Tombol nonaktif (null) jika bukan hari ini
                onPressed: (isToday && !_isLoading) ? () {
                  _handleMarkAsReady(batchOrders);
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isToday ? Theme.of(context).primaryColor : Colors.grey,
                ),
                child: const Text('Tandai Semua Siap Diambil'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}