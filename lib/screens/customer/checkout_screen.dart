// File: lib/screens/customer/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

import '../../models/subscription_slot.dart'; // Import Model Slot (PENTING)
import '../../services/customer_service.dart';
import '../maps/location_picker_screen.dart';
import '../../utils/location_utils.dart';

class CheckoutScreen extends StatefulWidget {
  // KITA UBAH INI: Menerima List Slot, bukan CartItems
  final List<SubscriptionSlot> slots;

  const CheckoutScreen({
    Key? key,
    required this.slots,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CustomerService _customerService = CustomerService();
  bool _isLoading = false;
  
  // Variabel Lokasi & Ongkir
  LatLng? _userLocation;
  double? _restoLat;
  double? _restoLng;
  double _distanceKm = 0.0;
  int _shippingCost = 0;
  String? _errorMsg;

  // Variabel Harga
  int _totalFoodPrice = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotalPrice();
    _fetchRestaurantLocation();
  }

  // Hitung total harga makanan dari slot yang dipilih
  void _calculateTotalPrice() {
    int total = 0;
    for (var slot in widget.slots) {
      if (slot.selectedMenu != null) {
        total += slot.selectedMenu!.harga;
      }
    }
    setState(() {
      _totalFoodPrice = total;
    });
  }

  // Ganti fungsi ini di checkout_screen.dart
  Future<void> _fetchRestaurantLocation() async {
    // 1. Cek apakah slot ada isinya
    if (widget.slots.isEmpty) {
      print("DEBUG FATAL: Slot kosong!");
      return;
    }
    
    // 2. Cek apakah menu dipilih
    final firstSlot = widget.slots.first;
    if (firstSlot.selectedMenu == null) {
      print("DEBUG FATAL: Menu pada slot pertama NULL!");
      return;
    }

    // 3. Intip ID Restoran yang dibawa menu
    final String restoId = firstSlot.selectedMenu!.restaurantId;
    print("DEBUG 1: ID Restoran dari Menu = '$restoId'");

    if (restoId.isEmpty) {
      setState(() {
        _errorMsg = "ERROR DATA: ID Restoran Kosong. Hapus keranjang & pesan ulang.";
      });
      return;
    }
    
    // 4. Panggil Service
    print("DEBUG 2: Memanggil Firebase untuk ID: $restoId...");
    final resto = await _customerService.getRestaurantById(restoId);
    
    if (resto == null) {
      print("DEBUG 3: Data Restoran TIDAK DITEMUKAN di Firebase.");
      setState(() => _errorMsg = "Data restoran hilang dari server.");
      return;
    }

    // 5. Intip Data Lokasi yang didapat
    print("DEBUG 4: Data Diterima -> Nama: ${resto.namaToko}");
    print("DEBUG 5: Latitude: ${resto.latitude} (Tipe: ${resto.latitude.runtimeType})");
    print("DEBUG 6: Longitude: ${resto.longitude} (Tipe: ${resto.longitude.runtimeType})");

    if (mounted) {
      // Logika Penentuan
      if (resto.latitude != 0 && resto.longitude != 0) {
        print("DEBUG SUKSES: Lokasi Valid! Menyimpan ke state.");
        setState(() {
          _restoLat = resto.latitude;
          _restoLng = resto.longitude;
        });
      } else {
        print("DEBUG GAGAL: Lokasi masih 0.0 (Default).");
        setState(() {
          _errorMsg = "Restoran belum mengatur lokasi (Lat/Lng masih 0).";
        });
      }
    }
  }

  void _pickLocation() async {
    if (_restoLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data lokasi restoran tidak valid.'))
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && result is LatLng) {
      _calculateShipping(result);
    }
  }

  // --- LOGIKA ONGKIR BARU (Support 2x Makan) ---
  void _calculateShipping(LatLng userLoc) {
    if (_restoLat == null || _restoLng == null) return;

    // 1. Hitung Jarak (KM)
    double dist = LocationUtils.calculateDistance(
      _restoLat!, _restoLng!, 
      userLoc.latitude, userLoc.longitude
    );

    // 2. Validasi Maksimal 5 KM
    if (dist > 5.0) {
      setState(() {
        _userLocation = null;
        _distanceKm = 0;
        _shippingCost = 0;
        _errorMsg = "Kejauhan (${dist.toStringAsFixed(1)} KM). Max 5 KM.";
      });
      return;
    }

    // 3. Deteksi Durasi & Frekuensi Makan
    int maxDay = 0;
    if (widget.slots.isNotEmpty) {
      // Cari hari paling besar (misal 30)
      for (var slot in widget.slots) {
        if (slot.day > maxDay) maxDay = slot.day;
      }
    }
    
    // Hitung Frekuensi Makan per Hari (1x atau 2x)
    // Rumus: Total Slot dibagi Total Hari
    // Contoh: 14 slot / 7 hari = 2x makan.
    int mealsPerDay = 1;
    if (maxDay > 0) {
      mealsPerDay = (widget.slots.length / maxDay).ceil();
    }

    // 4. Hitung Biaya Dasar Per Trip (Rp 4.000 per KM)
    // Jarak < 1 KM tetap dihitung 1 KM
    double payableDist = dist < 1.0 ? 1.0 : dist;
    double baseCostPerTrip = payableDist * 4000; 

    // 5. Terapkan Multiplier Durasi (Strategi Diskon Anda)
    double durationMultiplier = 1.0;
    if (maxDay <= 7) {
      durationMultiplier = 1.0;      // 7 Hari = Harga Normal
    } else if (maxDay <= 14) {
      durationMultiplier = 1.5;      // 14 Hari = Diskon (Cuma bayar 1.5x)
    } else {
      durationMultiplier = 2.0;      // 30 Hari = Diskon Besar (Cuma bayar 2x)
    }

    // 6. HITUNG TOTAL AKHIR
    // Rumus: (Biaya Trip x Durasi) x Frekuensi Makan
    double totalCost = (baseCostPerTrip * durationMultiplier) * mealsPerDay;

    // Pembulatan ke atas
    int fixedCost = totalCost.ceil();

    setState(() {
      _userLocation = userLoc;
      _distanceKm = dist;
      _shippingCost = fixedCost;
      _errorMsg = null; 
    });
    
    // Debugging untuk cek logika
    print("DEBUG ONGKIR:");
    print("- Jarak: ${dist.toStringAsFixed(2)} KM");
    print("- Durasi: $maxDay Hari (Multiplier: $durationMultiplier)");
    print("- Frekuensi: $mealsPerDay x Makan/Hari");
    print("- Total Ongkir: Rp $fixedCost");
  }

  Future<void> _processPayment() async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih lokasi pengiriman dahulu!')));
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final int finalTotal = _totalFoodPrice + _shippingCost;
      final url = Uri.parse('https://katering-app.vercel.app/createTransaction'); 

      // Konversi Data Slots ke JSON
      final List<Map<String, dynamic>> slotsData = widget.slots.map((slot) {
        return {
          'day': slot.day,
          'mealTime': slot.mealTime,
          'selectedMenu': {
            'menuId': slot.selectedMenu!.menuId,
            'namaMenu': slot.selectedMenu!.namaMenu,
            'harga': slot.selectedMenu!.harga,
            'fotoUrl': slot.selectedMenu!.fotoUrl,
            'restaurantId': slot.selectedMenu!.restaurantId,
          }
        };
      }).toList();

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'finalPrice': finalTotal,
          'userId': user.uid,
          'slots': slotsData,
          'shippingCost': _shippingCost,
          'userLat': _userLocation!.latitude,
          'userLng': _userLocation!.longitude,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentWebViewScreen(paymentUrl: responseData['paymentUrl']),
            ),
          );
        }
      } else {
        throw Exception('Gagal: ${responseData['error']}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int grandTotal = _totalFoodPrice + _shippingCost;
    bool isLocationSelected = _userLocation != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Langganan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- LIST SLOT MENU ---
          const Text('Rincian Paket Menu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          
          // Tampilkan list slot secara ringkas
          ListView.builder(
            shrinkWrap: true, // Agar bisa dalam ListView parent
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.slots.length,
            itemBuilder: (context, index) {
              final slot = widget.slots[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restaurant, size: 20, color: Colors.grey),
                title: Text('Hari ${slot.day} - ${slot.mealTime}'),
                subtitle: Text(slot.selectedMenu?.namaMenu ?? '-'),
                trailing: Text('Rp ${slot.selectedMenu?.harga ?? 0}'),
              );
            },
          ),
          const Divider(),
          
          // --- PENGIRIMAN ---
          const SizedBox(height: 16),
          const Text('Lokasi Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          
          if (_errorMsg != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[50],
              child: Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
            ),

          Card(
            elevation: 1,
            color: Colors.blue[50],
            child: ListTile(
              leading: Icon(Icons.location_on, color: isLocationSelected ? Colors.green : Colors.orange),
              title: Text(isLocationSelected ? 'Lokasi Terpilih' : 'Pilih Lokasi Antar'),
              subtitle: Text(isLocationSelected 
                  ? 'Jarak: ${_distanceKm.toStringAsFixed(1)} KM' 
                  : 'Wajib set lokasi untuk ongkir'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: _pickLocation,
            ),
          ),

          const SizedBox(height: 24),

          // --- RINGKASAN BIAYA ---
          _buildSummaryRow('Total Makanan', 'Rp $_totalFoodPrice'),
          _buildSummaryRow('Ongkos Kirim', 'Rp $_shippingCost', color: Colors.green[700]),
          const Divider(thickness: 1.5),
          _buildSummaryRow('Total Bayar', 'Rp $grandTotal', isBold: true, fontSize: 18),
          
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: (isLocationSelected && _errorMsg == null) ? Theme.of(context).primaryColor : Colors.grey,
              ),
              onPressed: (isLocationSelected && _errorMsg == null && !_isLoading) 
                  ? _processPayment 
                  : null,
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('BAYAR LANGGANAN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

// WebView Pembayaran
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  const PaymentWebViewScreen({Key? key, required this.paymentUrl}) : super(key: key);

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            if (url.contains('payment-success') || url.contains('status_code=200')) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembayaran Berhasil!'), backgroundColor: Colors.green));
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}