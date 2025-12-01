// File: lib/screens/onboarding/pending_verification_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Halaman yang ditampilkan saat pendaftaran mitra (restoran/driver)
/// sedang ditinjau oleh admin.
///
/// Halaman ini menerima [role] untuk menampilkan pesan yang sesuai.
class PendingVerificationScreen extends StatelessWidget {
  final String role;

  const PendingVerificationScreen({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    // Tentukan pesan kustom berdasarkan role
    final String message;
    if (role == 'restoran') {
      message =
          "Akun Anda sedang kami tinjau. Sesuai prosedur, tim kami akan mengunjungi lokasi Anda untuk verifikasi.";
    } else if (role == 'driver') {
      message =
          "Akun Anda sedang kami tinjau. Anda akan segera dihubungi untuk jadwal interview langsung.";
    } else {
      message = "Akun Anda sedang kami tinjau.";
    }

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
              // Tampilkan pesan yang sudah ditentukan
              Text(
                message,
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