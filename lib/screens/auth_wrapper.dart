// File: lib/screens/auth_wrapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth/login_screen.dart';
import 'onboarding/pending_verification_screen.dart';
import 'home_placeholder.dart';

/// Widget [AuthWrapper] adalah "Penjaga Gerbang" utama aplikasi.
/// Ia mendengarkan status login [FirebaseAuth] dan mengarahkan pengguna.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!authSnapshot.hasData) {
          // User belum login
          return const LoginScreen();
        }

        // User sudah login, cek data role-nya di Firestore
        return RoleBasedRedirect(user: authSnapshot.data!);
      },
    );
  }
}

/// Widget [RoleBasedRedirect] mengecek data role & status di Firestore
/// untuk mengarahkan pengguna yang sudah login ke halaman yang benar.
class RoleBasedRedirect extends StatelessWidget {
  final User user;
  const RoleBasedRedirect({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userDocSnapshot) {
        if (userDocSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // --- INI PERBAIKANNYA ---
        if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
          // Jika user login (Auth) tapi datanya (Firestore) tidak ada,
          // ini adalah state 'stale' atau 'corrupt'. Paksa logout.
          
          // Kita gunakan WidgetsBinding untuk memanggil signOut setelah build selesai
          // untuk menghindari error 'setState during build'.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAuth.instance.signOut();
          });
          
          // Tampilkan loading selagi proses logout
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        // --- SELESAI PERBAIKAN ---

        final data = userDocSnapshot.data!.data() as Map<String, dynamic>;

        if (data['role'] == null) {
          // Data user ada tapi 'role' belum ditulis (race condition)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final String role = data['role'];

        switch (role) {
          case 'pelanggan':
            return const HomePlaceholder();

          case 'restoran':
            // Cek status pendaftaran mitra di koleksi 'restaurants'
            return _CheckPartnerStatus(
              uid: user.uid,
              collection: 'restaurants',
              homePage: const HomePlaceholder(), // Nanti jadi RestoDashboard
            );

          case 'driver':
            return const HomePlaceholder(); // Placeholder dulu

          default:
            return const LoginScreen(); // Role tidak dikenal
        }
      },
    );
  }
}

/// Widget helper untuk cek status dokumen mitra ('pending', 'verified', dll)
class _CheckPartnerStatus extends StatelessWidget {
  final String uid;
  final String collection;
  final Widget homePage;

  const _CheckPartnerStatus({
    required this.uid,
    required this.collection,
    required this.homePage,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .snapshots(),
      builder: (context, partnerDocSnapshot) {
        if (partnerDocSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Jika dokumen mitra belum ada (error inkonsistensi data)
        if (!partnerDocSnapshot.hasData || !partnerDocSnapshot.data!.exists) {
          // Ini juga state error. Logout paksa.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAuth.instance.signOut();
          });
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Error: Data Mitra tidak ditemukan."),
                  ElevatedButton(
                    child: const Text('Logout'),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  )
                ],
              ),
            ),
          );
        }

        final data = partnerDocSnapshot.data!.data() as Map<String, dynamic>;

        if (data['status'] == null) {
          // Dokumen ada tapi 'status' belum ditulis
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final String status = data['status'];

        if (status == 'pending') {
          return const PendingVerificationScreen();
        }

        if (status == 'verified') {
          return homePage;
        }

        // Default case (misal: 'ditolak')
        return Scaffold(
            body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Akun Anda ditolak."),
              ElevatedButton(
                child: const Text('Logout'),
                onPressed: () => FirebaseAuth.instance.signOut(),
              )
            ],
          ),
        ));
      },
    );
  }
}