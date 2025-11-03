// File: lib/screens/restaurant/menu_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/menu_model.dart';
// import 'add_edit_menu_screen.dart'; // Akan digunakan di commit berikutnya

/// Halaman untuk mengelola (CRUD) menu oleh pemilik restoran.
class MenuManagementScreen extends StatelessWidget {
  const MenuManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Seharusnya tidak terjadi jika sudah dijaga AuthWrapper
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
            padding: const EdgeInsets.only(bottom: 80), // Padding untuk FAB
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
          // Akan diimplementasikan di commit berikutnya
          print('Navigasi ke Tambah Menu');
        },
      ),
    );
  }
}

/// Widget internal untuk menampilkan satu item menu dalam daftar.
class _MenuListItem extends StatelessWidget {
  final MenuModel menu;
  final String restoId;

  const _MenuListItem({
    Key? key,
    required this.menu,
    required this.restoId,
  }) : super(key: key);

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
        title: Text(menu.namaMenu),
        subtitle: Text('Rp ${menu.harga}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tombol Edit
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue[700]),
              tooltip: 'Edit Menu',
              onPressed: () {
                // Akan diimplementasikan di commit berikutnya
                print('Navigasi ke Edit Menu (ID: ${menu.menuId})');
              },
            ),
            // Tombol Hapus
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red[700]),
              tooltip: 'Hapus Menu',
              onPressed: () {
                // Akan diimplementasikan di commit berikutnya
                print('Tampilkan dialog hapus (ID: ${menu.menuId})');
              },
            ),
          ],
        ),
      ),
    );
  }
}