import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Halaman sementara untuk pengguna yang berhasil login.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Selamat Datang! (Ini Halaman Home)'),
      ),
    );
  }
}
