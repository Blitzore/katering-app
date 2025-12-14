// File: lib/screens/customer/customer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // Pastikan package ini sudah di pubspec.yaml
import '../../models/restaurant_model.dart';
import '../../services/customer_service.dart';
import '../../utils/location_utils.dart'; // Import Wajib
import 'widgets/restaurant_menu_section.dart'; // Pastikan file ini ada (Minggu 3-4)
import 'widgets/cart_badge.dart'; // Pastikan file ini ada
import 'my_orders_screen.dart'; // Pastikan file ini ada (Minggu 7)

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({Key? key}) : super(key: key);
  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final CustomerService _customerService = CustomerService();
  late Stream<List<RestaurantModel>> _restaurantStream;
  
  Position? _userPosition;
  bool _isLoadingLocation = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _restaurantStream = _customerService.getVerifiedRestaurants();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Layanan lokasi (GPS) mati.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Izin lokasi ditolak.';
      }
      
      if (permission == LocationPermission.deniedForever) throw 'Izin lokasi ditolak permanen.';

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userPosition = position;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString();
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katering Terdekat (5KM)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
          ),
          const CartBadge(), 
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingLocation) return const Center(child: CircularProgressIndicator());

    if (_locationError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 50, color: Colors.grey),
            Text(_locationError!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: _getUserLocation, child: const Text('Coba Lagi'))
          ],
        ),
      );
    }

    return StreamBuilder<List<RestaurantModel>>(
      stream: _restaurantStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Belum ada data restoran.'));

        final allRestaurants = snapshot.data!;
        
        // --- FILTER JARAK 5 KM ---
        final nearbyRestaurants = allRestaurants.where((resto) {
          if (resto.latitude == 0 || resto.longitude == 0) return false; // Sembunyikan resto tanpa lokasi
          
          double dist = LocationUtils.calculateDistance(
            _userPosition!.latitude, _userPosition!.longitude, 
            resto.latitude, resto.longitude
          );
          return dist <= 5.0; // Hanya radius 5KM
        }).toList();

        if (nearbyRestaurants.isEmpty) {
          return const Center(child: Text('Tidak ada restoran dalam radius 5KM.'));
        }

        return ListView.builder(
          itemCount: nearbyRestaurants.length,
          itemBuilder: (context, index) {
            final resto = nearbyRestaurants[index];
            double dist = LocationUtils.calculateDistance(
               _userPosition!.latitude, _userPosition!.longitude, 
               resto.latitude, resto.longitude
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text('${resto.namaToko} (${dist.toStringAsFixed(1)} km)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
                RestaurantMenuSection(restaurant: resto),
                const Divider(thickness: 4, color: Colors.black12),
              ],
            );
          },
        );
      },
    );
  }
}