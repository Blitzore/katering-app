// File: lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import halaman fitur admin lainnya
import 'admin_earnings_screen.dart';       // Halaman Pendapatan
import 'admin_manage_drivers.dart';        // Halaman Lokasi Driver
// import 'admin_verification_list.dart';  // (Jika ada file verifikasi lama)

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.purple[800], // Warna khas Admin
        foregroundColor: Colors.white,
        actions: [
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
          // --- MENU 1: PENDAPATAN PLATFORM (BARU) ---
          _buildDashboardCard(
            context,
            icon: Icons.monetization_on,
            title: 'Pendapatan Platform',
            subtitle: 'Cek komisi 10% & ongkir',
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminEarningsScreen()),
              );
            },
          ),
          
          // --- MENU 2: LOKASI MANGKAL DRIVER (BARU) ---
          _buildDashboardCard(
            context,
            icon: Icons.map,
            title: 'Lokasi Mangkal Driver',
            subtitle: 'Set titik mangkal driver',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminManageDriversScreen()),
              );
            },
          ),

          // --- MENU 3: VERIFIKASI MITRA (LAMA) ---
          _buildDashboardCard(
            context,
            icon: Icons.verified_user,
            title: 'Verifikasi Mitra',
            subtitle: 'Setujui pendaftar baru',
            color: Colors.blue,
            onTap: () {
              // Pastikan rute '/admin_verification_list' sudah terdaftar di main.dart
              // Atau gunakan Navigator.push manual jika error
              Navigator.pushNamed(context, '/admin_verification_list');
            },
          ),
        ],
      ),
    );
  }

  /// Widget helper untuk membuat card menu
  Widget _buildDashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color, // Tambahan parameter warna
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}