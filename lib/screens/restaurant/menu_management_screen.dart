// File: lib/screens/restaurant/menu_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/menu_model.dart';
import 'add_edit_menu_screen.dart'; // Import halaman form
import '../../services/restaurant_service.dart'; // Import service

/// Halaman untuk mengelola (CRUD) menu oleh pemilik restoran.
class MenuManagementScreen extends StatelessWidget {
  const MenuManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Anda harus login ulang.')));
    }

    /// Query ke subkoleksi 'menus' milik restoran yang sedang login.
    final Stream<QuerySnapshot> menuStream = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(user.uid)
        .collection('menus')
        .orderBy('namaMenu')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Menu Saya'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: menuStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Anda belum memiliki menu.\nKlik tombol + untuk menambah.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final menus = snapshot.data!.docs
              .map((doc) => MenuModel.fromSnapshot(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: menus.length,
            itemBuilder: (context, index) {
              final menu = menus[index];
              return _MenuListItem(
                menu: menu,
                restoId: user.uid,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        tooltip: 'Tambah Menu Baru',
        onPressed: () {
          // Navigasi ke Halaman Tambah (mode Tambah)
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AddEditMenuScreen(restoId: user.uid)),
          );
        },
      ),
    );
  }
}

/// Widget internal untuk menampilkan satu item menu dalam daftar.
class _MenuListItem extends StatelessWidget {
  final MenuModel menu;
  final String restoId;
  // Tambahkan instance service
  final RestaurantService _service = RestaurantService();

  _MenuListItem({
    Key? key,
    required this.menu,
    required this.restoId,
  }) : super(key: key);
  
  /// Menampilkan dialog konfirmasi sebelum menghapus
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Menu?'),
        content: Text('Anda yakin ingin menghapus "${menu.namaMenu}"?'),
        actions: [
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, Hapus'),
            onPressed: () async {
              Navigator.of(ctx).pop(); // Tutup dialog
              try {
                await _service.deleteMenu(restoId: restoId, menuId: menu.menuId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Menu berhasil dihapus'),
                  backgroundColor: Colors.green),
                );
              } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menghapus: $e'),
                  backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            menu.fotoUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image),
          ),
        ),
        title: Text(
          menu.namaMenu,
          style: TextStyle(
            decoration: !menu.isAvailable 
                ? TextDecoration.lineThrough 
                : TextDecoration.none,
            color: !menu.isAvailable ? Colors.grey : null,
          ),
        ),
        subtitle: Text('Rp ${menu.harga}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tombol Edit
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue[700]),
              tooltip: 'Edit Menu',
              onPressed: () {
                // Navigasi ke Halaman Edit (mode Edit)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditMenuScreen(
                      restoId: restoId,
                      menu: menu, // <-- Kirim data menu
                    ),
                  ),
                );
              },
            ),
            // Tombol Hapus
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red[700]),
              tooltip: 'Hapus Menu',
              onPressed: () {
                // Panggil dialog konfirmasi hapus
                _showDeleteDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}