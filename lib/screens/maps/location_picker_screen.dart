// File: lib/screens/maps/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({Key? key, this.initialLat, this.initialLng}) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  // Default: Monas, Jakarta (Jika belum ada lokasi)
  LatLng _currentCenter = const LatLng(-6.175392, 106.827153);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // 1. Jika ada lokasi awal (dari database), pakai itu
    if (widget.initialLat != null && widget.initialLng != null) {
      setState(() {
        _currentCenter = LatLng(widget.initialLat!, widget.initialLng!);
        _isLoading = false;
      });
      return;
    }

    // 2. Jika tidak, coba ambil lokasi GPS saat ini
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Layanan lokasi mati';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Izin lokasi ditolak';
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentCenter = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      // Jika gagal GPS, tetap pakai default (Monas)
      setState(() => _isLoading = false);
      print('Gagal ambil GPS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geser Peta untuk Memilih')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter, // Pakai initialCenter untuk v6
                    initialZoom: 15.0,
                    onPositionChanged: (position, hasGesture) {
                      if (position.center != null) {
                        // Jangan setState di sini agar tidak berat (rebuild terus)
                        _currentCenter = position.center!;
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.katering.app', 
                    ),
                  ],
                ),
                // --- PIN MERAH DI TENGAH ---
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40), // Angkat dikit biar pas ujung pin
                    child: Icon(Icons.location_on, size: 50, color: Colors.red),
                  ),
                ),
                // --- TOMBOL PILIH ---
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    onPressed: () {
                      // Kembalikan data LatLng ke halaman sebelumnya
                      Navigator.pop(context, _currentCenter);
                    },
                    child: const Text(
                      'PILIH LOKASI INI',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}