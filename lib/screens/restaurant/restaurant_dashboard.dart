// File: lib/screens/restaurant/restaurant_dashboard.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'menu_management_screen.dart';
import 'upcoming_orders_screen.dart';
import 'restaurant_profile_screen.dart'; // <-- IMPORT BARU (Pastikan file ini sudah dibuat)

/// Halaman dashboard utama untuk Restoran.
class RestaurantDashboard extends StatelessWidget {
  const RestaurantDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dasbor Restoran'),
        actions: [
          // --- [TOMBOL 1: AKSES CEPAT PROFIL] ---
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profil & Lokasi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RestaurantProfileScreen()),
              );
            },
          ),
          // --- [TOMBOL 2: LOGOUT] ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- KARTU 1: PESANAN ---
          _buildDashboardCard(
            context,
            icon: Icons.receipt_long,
            title: 'Pesanan Mendatang',
            subtitle: 'Lihat pesanan & Auto-Dispatch Driver',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UpcomingOrdersScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // --- KARTU 2: KELOLA MENU ---
          _buildDashboardCard(
            context,
            icon: Icons.restaurant_menu,
            title: 'Kelola Menu',
            subtitle: 'Tambah, edit, atau hapus menu Anda',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MenuManagementScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // --- KARTU 3: PROFIL & LOKASI (BARU) ---
          _buildDashboardCard(
            context,
            icon: Icons.store_mall_directory, // Ikon Toko/Lokasi
            title: 'Profil & Lokasi',
            subtitle: 'Atur titik peta untuk Ongkos Kirim', // Keterangan fungsi
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RestaurantProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Widget helper untuk membuat card menu di dashboard.
  Widget _buildDashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell( // Pakai InkWell biar ada efek pencet
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}