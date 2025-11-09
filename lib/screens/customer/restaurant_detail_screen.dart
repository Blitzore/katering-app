// File: lib/screens/customer/restaurant_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/menu_model.dart';
import '../../models/restaurant_model.dart';
import 'widgets/menu_card.dart'; // Kita gunakan ulang menu card

/// Halaman yang menampilkan semua menu dari satu restoran.
class RestaurantDetailScreen extends StatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantDetailScreen({Key? key, required this.restaurant})
      : super(key: key);

  @override
  _RestaurantDetailScreenState createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late Stream<List<MenuModel>> _menuStream;

  @override
  void initState() {
    super.initState();
    // Query untuk mengambil SEMUA menu dari resto ini
    _menuStream = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurant.id)
        .collection('menus')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MenuModel.fromSnapshot(doc)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurant.namaToko),
      ),
      body: StreamBuilder<List<MenuModel>>(
        stream: _menuStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Gagal memuat menu.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Restoran ini belum memiliki menu.'));
          }

          final menus = snapshot.data!;

          // Tampilkan sebagai GridView seperti di Halaman Home awal
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 kolom
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.75, // Rasio Tampilan Kartu
            ),
            itemCount: menus.length,
            itemBuilder: (context, index) {
              final menu = menus[index];
              return MenuCard(menu: menu); // MenuCard di sini
            },
          );
        },
      ),
    );
  }
}