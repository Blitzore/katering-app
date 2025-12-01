// File: lib/screens/auth_wrapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import halaman-halaman utama
import 'auth/login_screen.dart';
import 'onboarding/pending_verification_screen.dart';
import 'home_placeholder.dart';
import 'admin/admin_dashboard_screen.dart';
import 'restaurant/restaurant_dashboard.dart';
import 'customer/customer_home_screen.dart';
import 'driver/driver_dashboard.dart'; // <-- Import Dashboard Driver

/// Widget [AuthWrapper] adalah "Penjaga Gerbang" utama aplikasi.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Menunggu koneksi auth...
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

        if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final data = userDocSnapshot.data!.data() as Map<String, dynamic>;

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
            return const CustomerHomeScreen();
          case 'restoran':
            return _CheckPartnerStatus(
              uid: user.uid,
              collection: 'restaurants',
              homePage: const RestaurantDashboard(), 
              role: role,
            );
          case 'driver':
            return _CheckPartnerStatus(
              uid: user.uid,
              collection: 'drivers',
              // Arahkan ke Driver Dashboard
              homePage: const DriverDashboard(), 
              role: role,
            );
          default:
            return const LoginScreen();
        }
      },
    );
  }
}

/// Widget helper untuk cek status mitra ('pending', 'verified', 'ditolak')
class _CheckPartnerStatus extends StatelessWidget {
  final String uid;
  final String collection;
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
        
        if (partnerDocSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!partnerDocSnapshot.hasData || !partnerDocSnapshot.data!.exists) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final data = partnerDocSnapshot.data!.data() as Map<String, dynamic>;

        if (data['status'] == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final String status = data['status'];

        if (status == 'pending') {
          return PendingVerificationScreen(role: role);
        }

        if (status == 'verified') {
          return homePage;
        }

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