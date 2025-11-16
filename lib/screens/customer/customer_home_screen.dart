// File: lib/screens/customer/customer_home_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/restaurant_model.dart';
import '../../services/customer_service.dart';
import 'widgets/restaurant_menu_section.dart';
import 'widgets/cart_badge.dart'; // Import widget baru

/// Halaman utama (Home) untuk pelanggan.
/// Menampilkan daftar restoran, masing-masing dengan daftar menu horizontal.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({Key? key}) : super(key: key);

  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final CustomerService _customerService = CustomerService();
  late Stream<List<RestaurantModel>> _restaurantStream;

  @override
  void initState() {
    super.initState();
    _restaurantStream = _customerService.getVerifiedRestaurants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Menu Katering'),
        actions: [
          const CartBadge(), // Tambahkan Ikon Keranjang di sini
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: StreamBuilder<List<RestaurantModel>>(
        stream: _restaurantStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada restoran yang tersedia saat ini.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final restaurants = snapshot.data!;

          // Tampilkan sebagai ListView vertikal
          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final resto = restaurants[index];
              // Setiap item adalah section baru yang akan mengambil menunya sendiri
              return RestaurantMenuSection(restaurant: resto);
            },
          );
        },
      ),
    );
  }
}