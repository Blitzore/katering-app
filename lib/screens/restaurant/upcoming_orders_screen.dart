// File: lib/screens/restaurant/upcoming_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/daily_order_model.dart';
import '../../services/restaurant_service.dart';
import 'restaurant_profile_screen.dart'; // Import halaman profil

class UpcomingOrdersScreen extends StatefulWidget {
  const UpcomingOrdersScreen({Key? key}) : super(key: key);

  @override
  State<UpcomingOrdersScreen> createState() => _UpcomingOrdersScreenState();
}

class _UpcomingOrdersScreenState extends State<UpcomingOrdersScreen> {
  late Stream<List<DailyOrderModel>> _ordersStream;
  final String _restoId = FirebaseAuth.instance.currentUser!.uid;
  final RestaurantService _service = RestaurantService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ordersStream = _fetchUpcomingOrders();
  }

  Timestamp _getStartOfToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return Timestamp.fromDate(startOfDay);
  }
  
  Timestamp _getEndOf10Days() {
    final now = DateTime.now();
    final endOf10Days = DateTime(now.year, now.month, now.day + 9, 23, 59, 59);
    return Timestamp.fromDate(endOf10Days);
  }

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

  Future<void> _handleMarkAsReady(List<DailyOrderModel> batchOrders) async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // [PERBAIKAN DI SINI]: Menggunakan .orderId bukan .id
    final orderIds = batchOrders.map((order) => order.orderId).toList();

    try {
      // Panggil fungsi AUTO-ASSIGN
      await _service.autoAssignOrdersToDriver(orderIds);
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Sistem sedang mencari driver terdekat... Berhasil!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal: ${e.toString()}'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profil Restoran & Lokasi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RestaurantProfileScreen()),
              );
            },
          )
        ],
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
                return Center(
                  // Pesan error lebih informatif
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error: ${snapshot.error}.\n\nTips: Cek Firestore Index di Console jika baru pertama kali dijalankan.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
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
              
              // GROUPING: Kelompokkan berdasarkan tanggal + waktu makan
              final Map<String, List<DailyOrderModel>> groupedOrders = {};
              
              for (final order in orders) {
                String dateKey = DateFormat('yyyy-MM-dd').format(order.deliveryDate.toDate());
                String groupKey = '$dateKey-${order.mealTime}';
                
                if (!groupedOrders.containsKey(groupKey)) {
                  groupedOrders[groupKey] = [];
                }
                groupedOrders[groupKey]!.add(order);
              }
              
              final groupKeys = groupedOrders.keys.toList();

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: groupKeys.length,
                itemBuilder: (context, index) {
                  final key = groupKeys[index];
                  final batchOrders = groupedOrders[key]!;
                  return _buildBatchCard(context, key, batchOrders);
                },
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(BuildContext context, String groupKey, List<DailyOrderModel> batchOrders) {
    final deliveryDate = batchOrders.first.deliveryDate.toDate();
    final mealTime = batchOrders.first.mealTime;
    final tglKirim = DateFormat.yMMMd('id_ID').format(deliveryDate);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deliveryDay = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
    
    final bool isToday = deliveryDay.isAtSameMomentAs(today);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text('$tglKirim - $mealTime', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Total ${batchOrders.length} porsi'),
            tileColor: (isToday ? Colors.green[50] : Colors.grey[100]),
            trailing: isToday 
              ? const Chip(label: Text("HARI INI", style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.green)
              : null,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: batchOrders.map((order) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          order.fotoUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => Container(
                            width: 50, height: 50, color: Colors.grey[300], 
                            child: const Icon(Icons.fastfood, color: Colors.grey)
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.namaMenu,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text("ID Order: ...${order.orderId.substring(order.orderId.length - 4)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                // Tombol hanya aktif jika pesanan untuk HARI INI
                onPressed: (isToday && !_isLoading) ? () {
                  _handleMarkAsReady(batchOrders);
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isToday ? Theme.of(context).primaryColor : Colors.grey[300],
                  foregroundColor: isToday ? Colors.white : Colors.grey[600],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isToday ? 'TANDAI SIAP & PANGGIL DRIVER' : 'Belum Waktunya'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}