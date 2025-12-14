// File: lib/screens/restaurant/restaurant_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- IMPORT LAYAR FITUR LAINNYA ---
import 'menu_management_screen.dart';       // Kelola Menu
import 'restaurant_earnings_screen.dart';   // Penghasilan (Commit 3)
import 'restaurant_profile_screen.dart';    // Profil & Lokasi

// [PERBAIKAN] Menggunakan UpcomingOrdersScreen sesuai file Anda
import 'upcoming_orders_screen.dart';       

class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({Key? key}) : super(key: key);

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  final User? user = FirebaseAuth.instance.currentUser;

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Error: No User")));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dashboard Restoran'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER PROFIL ---
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('restaurants').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(); 
                
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final namaToko = data?['namaToko'] ?? 'Restoran Anda';
                final lat = data?['latitude'] ?? 0.0;
                bool isLocationSet = (lat != 0.0);

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade800, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, $namaToko!',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isLocationSet ? Icons.check_circle : Icons.warning,
                            color: isLocationSet ? Colors.lightGreenAccent : Colors.orangeAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isLocationSet ? 'Lokasi Aktif' : 'Lokasi Belum Diatur!',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Text("Menu Utama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // --- GRID MENU ---
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, 
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                // 1. Pesanan Masuk (UPCOMING)
                _buildMenuCard(
                  title: 'Pesanan Masuk',
                  icon: Icons.receipt_long,
                  color: Colors.orange,
                  onTap: () {
                    // [PERBAIKAN] Navigasi ke UpcomingOrdersScreen
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UpcomingOrdersScreen()));
                  },
                ),
                
                // 2. Kelola Menu
                _buildMenuCard(
                  title: 'Kelola Menu',
                  icon: Icons.restaurant_menu,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuManagementScreen()));
                  },
                ),

                // 3. Penghasilan (Fitur Baru)
                _buildMenuCard(
                  title: 'Penghasilan',
                  icon: Icons.monetization_on,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantEarningsScreen()));
                  },
                ),

                // 4. Profil & Lokasi
                _buildMenuCard(
                  title: 'Profil & Lokasi',
                  icon: Icons.store,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantProfileScreen()));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}