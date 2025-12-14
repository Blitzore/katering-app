// File: lib/screens/maps/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  
  // [BARU] Parameter ini yang dibutuhkan oleh fitur Admin
  final bool isSelecting; 

  const LocationPickerScreen({
    Key? key, 
    this.initialLat, 
    this.initialLng,
    this.isSelecting = true, // Default true (Mode Memilih)
  }) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  // Default: Monas, Jakarta
  LatLng _currentCenter = const LatLng(-6.175392, 106.827153);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // 1. Jika ada lokasi awal
    if (widget.initialLat != null && widget.initialLng != null) {
      setState(() {
        _currentCenter = LatLng(widget.initialLat!, widget.initialLng!);
        _isLoading = false;
      });
      return;
    }

    // 2. Jika tidak, ambil GPS (Hanya jika mode selecting)
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Layanan lokasi mati';

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
      // Fallback ke default
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelecting ? 'Geser Peta untuk Memilih' : 'Lokasi'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 15.0,
                    // Update posisi tengah saat peta digeser (hanya jika mode memilih)
                    onPositionChanged: (position, hasGesture) {
                      if (widget.isSelecting && position.center != null) {
                        _currentCenter = position.center!;
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.katering.app', 
                    ),
                    // [BARU] Jika MODE VIEW (Bukan memilih), tampilkan Marker biasa
                    if (!widget.isSelecting)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentCenter,
                            width: 50,
                            height: 50,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                  ],
                ),
                
                // [MODIFIKASI] Pin Tengah & Tombol hanya muncul di MODE MEMILIH
                if (widget.isSelecting) ...[
                  // --- PIN MERAH DI TENGAH ---
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 40),
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
                        Navigator.pop(context, _currentCenter);
                      },
                      child: const Text(
                        'PILIH LOKASI INI',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ]
              ],
            ),
    );
  }
}