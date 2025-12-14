// File: lib/screens/restaurant/restaurant_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../services/restaurant_service.dart';
import '../maps/location_picker_screen.dart';

class RestaurantProfileScreen extends StatefulWidget {
  const RestaurantProfileScreen({Key? key}) : super(key: key);

  @override
  State<RestaurantProfileScreen> createState() => _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  final RestaurantService _service = RestaurantService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  void _openMapPicker(double? currentLat, double? currentLng) async {
    // Navigasi ke layar peta, tunggu hasil balikan (result)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLat: currentLat,
          initialLng: currentLng,
        ),
      ),
    );

    // Jika user menekan tombol "Pilih" di peta, result akan berisi LatLng
    if (result != null && result is LatLng) {
      try {
        await _service.updateRestaurantLocation(_uid, result.latitude, result.longitude);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lokasi berhasil diperbarui!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Restoran')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _service.getRestaurantProfile(_uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Data profil tidak ditemukan.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String nama = data['namaToko'] ?? 'Nama Toko';
          final String alamat = data['alamat'] ?? 'Alamat belum diisi';
          
          // Ambil latitude/longitude (bisa null jika belum diset)
          final double? lat = (data['latitude'] as num?)?.toDouble();
          final double? lng = (data['longitude'] as num?)?.toDouble();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.store, size: 50),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                nama,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                alamat,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Lokasi Peta',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.map, color: Colors.blue),
                  title: Text(lat != null ? 'Lokasi Tersimpan' : 'Belum Ada Lokasi'),
                  subtitle: Text(lat != null 
                      ? 'Lat: $lat\nLng: $lng' 
                      : 'Harap set lokasi agar sistem bisa menghitung ongkir.'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _openMapPicker(lat, lng),
                ),
              ),
              
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout / Keluar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => FirebaseAuth.instance.signOut(),
              )
            ],
          );
        },
      ),
    );
  }
}