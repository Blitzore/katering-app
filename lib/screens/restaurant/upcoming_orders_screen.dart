// File: lib/screens/restaurant/upcoming_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Pastikan import model dan service ini benar sesuai struktur folder Anda
import '../../models/daily_order_model.dart';
import '../../services/restaurant_service.dart';
import 'restaurant_profile_screen.dart'; 

class UpcomingOrdersScreen extends StatefulWidget {
  const UpcomingOrdersScreen({Key? key}) : super(key: key);

  @override
  State<UpcomingOrdersScreen> createState() => _UpcomingOrdersScreenState();
}

class _UpcomingOrdersScreenState extends State<UpcomingOrdersScreen> {
  late Stream<List<DailyOrderModel>> _ordersStream;
  final String _restoId = FirebaseAuth.instance.currentUser!.uid;
  final RestaurantService _service = RestaurantService(); // Service untuk panggil backend
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ordersStream = _fetchUpcomingOrders();
  }

  Stream<List<DailyOrderModel>> _fetchUpcomingOrders() {
    final now = DateTime.now();
    final startOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    
    return FirebaseFirestore.instance
        .collection('daily_orders')
        .where('restaurantId', isEqualTo: _restoId)
        .where('status', whereIn: ['confirmed', 'assigned']) 
        .where('deliveryDate', isGreaterThanOrEqualTo: startOfToday)
        .orderBy('deliveryDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DailyOrderModel.fromSnapshot(doc)).toList());
  }

  Future<void> _manualRetryBooking(List<DailyOrderModel> batchOrders) async {
    setState(() => _isLoading = true);
    final orderIds = batchOrders.map((order) => order.orderId).toList();
    
    try {
      await _service.autoAssignOrdersToDriver(orderIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sistem sedang mencari driver ulang...'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFoodReady(List<DailyOrderModel> batchOrders) async {
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var order in batchOrders) {
        final ref = FirebaseFirestore.instance.collection('daily_orders').doc(order.orderId);
        batch.update(ref, {'status': 'ready_for_pickup'});
      }
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status update: SIAP! Driver akan segera menjemput.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Masuk'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantProfileScreen())),
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
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Belum ada pesanan aktif.'),
                    ],
                  ),
                );
              }
              
              final orders = snapshot.data!;
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
                padding: const EdgeInsets.all(16),
                itemCount: groupKeys.length,
                itemBuilder: (context, index) {
                  return _buildBatchCard(groupedOrders[groupKeys[index]]!);
                },
              );
            },
          ),
          
          if (_isLoading) 
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(List<DailyOrderModel> batchOrders) {
    final first = batchOrders.first;
    final tgl = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(first.deliveryDate.toDate());
    final now = DateTime.now();
    final orderDate = first.deliveryDate.toDate();
    final isToday = (now.year == orderDate.year && now.month == orderDate.month && now.day == orderDate.day);

    bool isAssigned = first.status == 'assigned';
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- HEADER CARD ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAssigned ? Colors.green[50] : Colors.orange[50],
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tgl, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(first.mealTime, style: TextStyle(color: Colors.grey[800])),
                  ],
                ),
                if (isToday)
                  const Chip(
                    label: Text("HARI INI", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),

          // --- INFO DRIVER ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isAssigned ? Icons.motorcycle : Icons.search_off, 
                  color: isAssigned ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isAssigned 
                      ? 'Driver: ${first.driverName ?? "Driver"}' 
                      : 'BELUM DAPAT DRIVER',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAssigned ? Colors.green[700] : Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // --- LIST MENU ---
          ...batchOrders.map((o) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "${o.namaMenu} (x1)", 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  "#${o.orderId.substring(o.orderId.length - 4)}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          )),
          
          const Divider(height: 1),

          // --- TOMBOL AKSI ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (isToday && !_isLoading) ? () {
                  if (isAssigned) {
                    _handleFoodReady(batchOrders);
                  } else {
                    _manualRetryBooking(batchOrders);
                  }
                } : null,
                
                icon: Icon(isAssigned ? Icons.check_circle : Icons.refresh),
                label: Text(
                  isToday 
                    ? (isAssigned ? 'MAKANAN SIAP (PANGGIL DRIVER)' : 'CARI DRIVER ULANG')
                    : 'BELUM WAKTUNYA',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAssigned ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),

          // --- PERBAIKAN: TAMBAH JARAK BAWAH AGAR TOMBOL TIDAK KEPOTONG ---
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}