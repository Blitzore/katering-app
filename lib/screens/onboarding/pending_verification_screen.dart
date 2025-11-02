import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Halaman yang ditampilkan saat pendaftaran mitra sedang ditinjau.
class PendingVerificationScreen extends StatelessWidget {
  const PendingVerificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Menunggu Verifikasi")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              Text(
                "Pendaftaran Anda Telah Diterima",
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Akun Anda sedang kami tinjau. Sesuai prosedur, tim kami akan mengunjungi lokasi Anda untuk verifikasi.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 30),
              TextButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                },
                child: const Text('Logout'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
