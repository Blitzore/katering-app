// File: lib/screens/auth_wrapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth/login_screen.dart';
import 'onboarding/pending_verification_screen.dart';
import 'home_placeholder.dart';
import 'admin/admin_dashboard_screen.dart'; // Import untuk Admin
import 'restaurant/restaurant_dashboard.dart'; // Import untuk Restoran

/// Widget [AuthWrapper] adalah "Penjaga Gerbang" utama aplikasi.
///
/// Ia mendengarkan status login [FirebaseAuth] (authStateChanges)
/// dan mengarahkan pengguna ke halaman yang sesuai.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Menunggu koneksi...
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Jika user tidak login, arahkan ke LoginScreen
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // User sudah login, cek data role-nya di Firestore
        return RoleBasedRedirect(user: authSnapshot.data!);
      },
    );
  }
}

/// Widget [RoleBasedRedirect] mengecek data 'role' di koleksi 'users'
/// untuk mengarahkan pengguna yang sudah login.
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
        
        // Menunggu data user...
        if (userDocSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Jika data user belum ada (masih proses registrasi),
        // tetap tampilkan loading. Stream akan update saat data selesai ditulis.
        if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final data = userDocSnapshot.data!.data() as Map<String, dynamic>;

        // Jika data role belum tertulis (race condition)
        if (data['role'] == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final String role = data['role'];

        // Arahkan berdasarkan role
        switch (role) {
          case 'admin':
            return const AdminDashboardScreen();
          case 'pelanggan':
            return const HomePlaceholder();
          case 'restoran':
            // Jika restoran, cek status pendaftarannya di koleksi 'restaurants'
            return _CheckPartnerStatus(
              uid: user.uid,
              collection: 'restaurants',
              homePage: const RestaurantDashboard(), // <-- DIUBAH
              role: role,
            );
          case 'driver':
            // Jika driver, cek status pendaftarannya di koleksi 'drivers'
            return _CheckPartnerStatus(
              uid: user.uid,
              collection: 'drivers',
              homePage: const HomePlaceholder(), // Nanti jadi DriverDashboard
              role: role,
            );
          default:
            return const LoginScreen(); // Role tidak dikenal
        }
      },
    );
  }
}

/// Widget helper untuk cek status dokumen mitra ('pending', 'verified', 'ditolak')
/// di koleksi 'restaurants' atau 'drivers'.
class _CheckPartnerStatus extends StatelessWidget {
  final String uid;
  final String collection; // 'restaurants' atau 'drivers'
  final Widget homePage;
  final String role; 
  
  const _CheckPartnerStatus({
    required this.uid,
    required this.collection,
    required this.homePage,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .snapshots(),
      builder: (context, partnerDocSnapshot) {
        
        // Menunggu data mitra...
        if (partnerDocSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Jika data mitra (restaurants/drivers) belum ada,
        // tetap tampilkan loading. Stream akan update saat data selesai ditulis.
        if (!partnerDocSnapshot.hasData || !partnerDocSnapshot.data!.exists) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final data = partnerDocSnapshot.data!.data() as Map<String, dynamic>;

        // Jika data status belum tertulis (race condition)
        if (data['status'] == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final String status = data['status'];

        // Arahkan berdasarkan status pendaftaran
        if (status == 'pending') {
          return PendingVerificationScreen(role: role);
        }

        if (status == 'verified') {
          return homePage; // <-- Ini akan mengarah ke RestaurantDashboard
        }

        // Default (misal: 'ditolak' atau status lain)
        return Scaffold(
            body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Akun Anda ditolak atau diblokir."),
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