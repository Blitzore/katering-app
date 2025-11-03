// File: lib/screens/admin/admin_dashboard_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Halaman dashboard utama untuk Admin.
/// Menampilkan menu navigasi ke fitur-fitur admin.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // Aksi logout
              FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDashboardCard(
            context,
            icon: Icons.pending_actions,
            title: 'Verifikasi Mitra',
            subtitle: 'Setujui atau tolak pendaftar baru',
            onTap: () {
              Navigator.pushNamed(context, '/admin_verification_list');
            },
          ),
          // Nanti bisa ditambahkan card lain (misal: Statistik)
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
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        leading: Icon(
          icon,
          size: 40,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}